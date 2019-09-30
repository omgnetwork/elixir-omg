# Copyright 2019 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.ChildChain.BlockQueue.BlockQueueSubmitter do
  @moduledoc """

  """
  require Logger

  alias OMG.ChildChain.BlockQueue.BlockSubmission
  alias OMG.ChildChain.BlockQueue.BlockQueueLogger
  alias OMG.ChildChain.BlockQueue.BlockQueueState
  alias OMG.ChildChain.BlockQueue.GasPriceCalculator

  @type submit_result_t() :: {:ok, <<_::256>>} | {:error, map}

  @spec submit_blocks(BlockQueueState.t()) :: :ok
  def submit_blocks(%BlockQueueState{} = state) do
    state
    |> get_blocks_to_submit()
    |> Enum.each(&submit/1)
  end

  @doc """
  Compares the child blocks mined in contract with formed blocks

  Picks for submission child blocks that haven't yet been seen mined on Ethereum
  """
  @spec get_blocks_to_submit(BlockQueueState.t()) :: [BlockQueue.encoded_signed_tx()]
  def get_blocks_to_submit(%{blocks: blocks, formed_child_block_num: formed} = state) do
    _ = Logger.debug("preparing blocks #{inspect(GasPriceCalculator.first_to_mined(state))}..#{inspect(formed)} for submission")

    blocks
    |> Enum.filter(GasPriceCalculator.to_mined_block_filter(state))
    |> Enum.map(fn {_blknum, block} -> block end)
    |> Enum.sort_by(& &1.num)
    |> Enum.map(&Map.put(&1, :gas_price, state.gas_price_to_use))
  end

  defp submit(%BlockSubmission{hash: hash, nonce: nonce, gas_price: gas_price} = submission) do
    _ = Logger.debug("Submitting: #{inspect(submission)}")

    submit_result = RootChain.submit_block(hash, nonce, gas_price)
    {:ok, newest_mined_blknum} = RootChain.get_mined_child_block()

    final_result = process_submit_result(submission, submit_result, newest_mined_blknum)

    _ =
      case final_result do
        {:error, _} ->
          BlockQueueLogger.log(:eth_node_error)
        _ -> :ok
      end

    :ok = final_result
  end

  # TODO: consider moving this logic to separate module
  @spec process_submit_result(BlockSubmission.t(), submit_result_t(), BlockSubmission.plasma_block_num()) ::
          :ok | {:error, atom}
  def process_submit_result(submission, submit_result, newest_mined_blknum) do
    case submit_result do
      {:ok, txhash} ->
        _ = Logger.info("Submitted #{inspect(submission)} at: #{inspect(txhash)}")
        :ok

      {:error, %{"code" => -32_000, "message" => "known transaction" <> _}} ->
        _ = log_known_tx(submission)
        :ok

      # parity error code for duplicated tx
      {:error, %{"code" => -32_010, "message" => "Transaction with the same hash was already imported."}} ->
        _ = log_known_tx(submission)
        :ok

      {:error, %{"code" => -32_000, "message" => "replacement transaction underpriced"}} ->
        _ = log_low_replacement_price(submission)
        :ok

      # parity version
      {:error, %{"code" => -32_010, "message" => "Transaction gas price is too low. There is another" <> _}} ->
        _ = log_low_replacement_price(submission)
        :ok

      {:error, %{"code" => -32_000, "message" => "authentication needed: password or unlock"}} ->
        diagnostic = prepare_diagnostic(submission, newest_mined_blknum)
        _ = Logger.error("It seems that authority account is locked: #{inspect(diagnostic)}. Check README.md")
        {:error, :account_locked}

      {:error, %{"code" => -32_000, "message" => "nonce too low"}} ->
        process_nonce_too_low(submission, newest_mined_blknum)

      # parity specific error for nonce-too-low
      {:error, %{"code" => -32_010, "message" => "Transaction nonce is too low." <> _}} ->
        process_nonce_too_low(submission, newest_mined_blknum)
    end
  end

  defp log_known_tx(submission) do
    Logger.debug("Submission #{inspect(submission)} is known transaction - ignored")
  end

  defp log_low_replacement_price(submission) do
    Logger.debug("Submission #{inspect(submission)} is known, but with higher price - ignored")
  end

  defp process_nonce_too_low(%BlockSubmission{num: blknum} = submission, newest_mined_blknum) do
    if blknum <= newest_mined_blknum do
      # apparently the `nonce too low` error is related to the submission having been mined while it was prepared
      :ok
    else
      diagnostic = prepare_diagnostic(submission, newest_mined_blknum)
      _ = Logger.error("Submission unexpectedly failed with nonce too low: #{inspect(diagnostic)}")
      {:error, :nonce_too_low}
    end
  end

  defp prepare_diagnostic(submission, newest_mined_blknum) do
    config = Application.get_all_env(:omg_eth) |> Keyword.take([:contract_addr, :authority_addr, :txhash_contract])
    %{submission: submission, newest_mined_blknum: newest_mined_blknum, config: config}
  end
end
