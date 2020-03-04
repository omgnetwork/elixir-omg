# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain do
  @moduledoc """
  Entrypoint for all the exposed public functions of the child chain server's API.

  Should handle all the initial processing of requests like state-less validity, decoding/encoding
  (but not transport-specific encoding like hex).
  """
  use OMG.Utils.LoggerExt

  alias OMG.Block
  alias OMG.ChildChain.FeeServer
  alias OMG.ChildChain.FreshBlocks
  alias OMG.ChildChain.Measure
  alias OMG.Fees
  alias OMG.Fees.FeeFilter
  alias OMG.State
  alias OMG.State.Transaction

  @type submit_error() :: Transaction.Recovered.recover_tx_error() | State.exec_error() | :transaction_not_supported

  @spec submit(transaction :: binary) ::
          {:ok, %{txhash: Transaction.tx_hash(), blknum: pos_integer, txindex: non_neg_integer}}
          | {:error, submit_error()}
  def submit(transaction) do
    IO.puts("OMG.ChildChain.submit(): executing handler for '#{Measure.txn_submission_submitted()}'")
    :ok = :telemetry.execute([Measure.txn_submission_submitted()], Measure.measure(), %{transaction: transaction})

    with {:ok, recovered_tx} <- Transaction.Recovered.recover_from(transaction),
         :ok <- is_supported(recovered_tx),
         {:ok, fees} <- FeeServer.accepted_fees(),
         fees = Fees.for_transaction(recovered_tx, fees),
         {:ok, {tx_hash, blknum, tx_index}} <- State.exec(recovered_tx, fees) do

      txn_data = %{txhash: tx_hash, blknum: blknum, txindex: tx_index}

      IO.puts("OMG.ChildChain.submit(): executing handler for '#{Measure.txn_submission_succeeded()}'")
      :ok = :telemetry.execute([Measure.txn_submission_succeeded()], Measure.measure(), %{transaction: txn_data})

      {:ok, txn_data}
    else
      {:error, error_data} ->
        IO.puts("OMG.ChildChain.submit(): executing handler for '#{Measure.txn_submission_failed()}'")
        :ok = :telemetry.execute([Measure.txn_submission_failed()], Measure.measure(), %{error: error_data})
        {:error, error_data}
    end
    |> result_with_logging()
  end

  @spec get_block(hash :: binary) ::
          {:ok, %{hash: binary, transactions: list, blknum: integer}} | {:error, :not_found | :internal_error}
  def get_block(hash) do
    with {:ok, struct_block} <- FreshBlocks.get(hash) do
      {:ok, Block.to_api_format(struct_block)}
    end
    |> result_with_logging()
  end

  @spec get_filtered_fees(list(pos_integer()), list(String.t()) | nil) ::
          {:ok, Fees.full_fee_t()} | {:error, :currency_fee_not_supported}
  def get_filtered_fees(tx_types, currencies) do
    with {:ok, fees} <- FeeServer.current_fees() do
      FeeFilter.filter(fees, tx_types, currencies)
    end
    |> result_with_logging()
  end

  defp is_supported(%Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: %Transaction.Fee{}}}),
    do: {:error, :transaction_not_supported}

  defp is_supported(%Transaction.Recovered{}), do: :ok

  defp result_with_logging(result) do
    _ = Logger.debug(" resulted with #{inspect(result)}")
    result
  end
end
