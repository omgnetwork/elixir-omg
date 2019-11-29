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
  alias OMG.Fees
  alias OMG.State
  alias OMG.State.Transaction
  alias OMG.Status.Alert.Alarm

  @type submit_error() :: Transaction.Recovered.recover_tx_error() | State.exec_error()

  @spec submit(transaction :: binary) ::
          {:ok, %{txhash: Transaction.tx_hash(), blknum: pos_integer, txindex: non_neg_integer}}
          | {:error, submit_error()}
  def submit(transaction) do
    with {:ok, recovered_tx} <- Transaction.Recovered.recover_from(transaction),
         {:ok, fees} <- FeeServer.transaction_fees(),
         fees = Fees.for_transaction(recovered_tx, fees),
         {:ok, {tx_hash, blknum, tx_index}} <- State.exec(recovered_tx, fees) do
      {:ok, %{txhash: tx_hash, blknum: blknum, txindex: tx_index}}
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

  @spec get_alarms() :: {:ok, Alarm.raw_t()}
  def get_alarms, do: {:ok, Alarm.all()}

  @spec get_filtered_fees(list(String.t()) | nil) :: {:ok, Fees.fee_t()} | {:error, :currency_fee_not_supported}
  def get_filtered_fees(currencies) do
    with {:ok, fees} <- FeeServer.transaction_fees() do
      Fees.filter_fees(fees, currencies)
    end
    |> result_with_logging()
  end

  defp result_with_logging(result) do
    _ = Logger.debug(" resulted with #{inspect(result)}")
    result
  end
end
