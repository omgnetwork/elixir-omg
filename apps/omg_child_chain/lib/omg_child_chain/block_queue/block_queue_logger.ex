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

defmodule OMG.ChildChain.BlockQueue.BlockQueueLogger do
  @moduledoc """

  """
  require Logger

  alias OMG.Eth.Encoding
  alias OMG.Eth.Diagnostics

  def log(event), do: do_log(event, nil)
  def log(event, args), do: do_log(event, args)

  defp do_log(:starting, module) do
    Logger.info("Starting #{module} service.")
  end

  defp do_log(:init_error, fields) do
    config = Diagnostics.get_child_chain_config()
    fields = Keyword.update!(fields, :known_hashes, fn hashes -> Enum.map(hashes, &Encoding.to_hex/1) end)
    diagnostic = fields |> Enum.into(%{config: config})

    _ =
      Logger.error(
        "The child chain might have not been wiped clean when starting a child chain from scratch: " <>
          "#{inspect(diagnostic)}. Check README.MD and follow the setting up child chain."
      )

    do_log(:eth_node_error, nil)
  end

  defp do_log(:eth_node_error, _) do
    eth_node_diagnostics = Diagnostics.get_node_diagnostics()
    _ = Logger.error("Ethereum operation failed, additional diagnostics: #{inspect(eth_node_diagnostics)}")
  end

  defp do_log(:known_tx, submission) do
    _ = Logger.debug("Submission #{inspect(submission)} is known transaction - ignored")
  end

  defp do_log(:submitted_block, %{submission: submission, txhash: txhash}) do
    _ = Logger.info("Submitted #{inspect(submission)} at: #{inspect(txhash)}")
  end

  defp do_log(:authority_locked, %{submission: submission, newest_mined_blknum: newest_mined_blknum}) do
    diagnostic = prepare_diagnostic(submission, newest_mined_blknum)
    _ = Logger.error("It seems that authority account is locked: #{inspect(diagnostic)}. Check README.md")
  end

  defp do_log(:low_replacement_price, submission) do
    _ = Logger.debug("Submission #{inspect(submission)} is known, but with higher price - ignored")
  end

  defp do_log(:nonce_too_low, %{submission: submission, newest_mined_blknum: newest_mined_blknum}) do
    diagnostic = prepare_diagnostic(submission, newest_mined_blknum)
    _ = Logger.error("Submission unexpectedly failed with nonce too low: #{inspect(diagnostic)}")
  end

  defp do_log(:preparing_blocks, %{
         first_block_to_mine_num: first_block_to_mine_num,
         formed_child_block_num: formed_child_block_num
       }) do
    _ =
      Logger.debug(
        "preparing blocks #{inspect(first_block_to_mine_num)}.." <>
          "#{inspect(formed_child_block_num)} for submission"
      )
  end

  defp do_log(:submitting_block, submission) do
    _ = Logger.debug("Submitting: #{inspect(submission)}")
  end

  defp prepare_diagnostic(submission, newest_mined_blknum) do
    config = Application.get_all_env(:omg_eth) |> Keyword.take([:contract_addr, :authority_addr, :txhash_contract])
    %{submission: submission, newest_mined_blknum: newest_mined_blknum, config: config}
  end
end
