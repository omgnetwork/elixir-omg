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
  alias OMG.Fees
  alias OMG.Fees.FeeFilter
  alias OMG.State
  alias OMG.State.Transaction

  @type submit_error() :: Transaction.Recovered.recover_tx_error() | State.exec_error() | :transaction_not_supported

  @spec submit(transaction :: binary) ::
          {:ok, %{txhash: Transaction.tx_hash(), blknum: pos_integer, txindex: non_neg_integer}}
          | {:error, submit_error()}
  def submit(transaction) do
    result =
      with {:ok, recovered_tx} <- Transaction.Recovered.recover_from(transaction),
           :ok <- is_supported(recovered_tx),
           {:ok, fees} <- FeeServer.accepted_fees(),
           fees = Fees.for_transaction(recovered_tx, fees),
           {:ok, {tx_hash, blknum, tx_index}} <- State.exec(recovered_tx, fees) do
        {:ok, %{txhash: tx_hash, blknum: blknum, txindex: tx_index}}
      end

    result_with_logging(result)
  end

  @spec get_block(hash :: binary) ::
          {:ok, %{hash: binary, transactions: list, blknum: integer}} | {:error, :not_found | :internal_error}
  def get_block(hash) do
    result =
      case FreshBlocks.get(hash) do
        {:ok, struct_block} ->
          {:ok, Block.to_api_format(struct_block)}

        error ->
          error
      end

    result_with_logging(result)
  end

  @spec get_filtered_fees(list(pos_integer()), list(String.t()) | nil) ::
          {:ok, Fees.full_fee_t()} | {:error, :currency_fee_not_supported}
  def get_filtered_fees(tx_types, currencies) do
    result =
      case FeeServer.current_fees() do
        {:ok, fees} ->
          FeeFilter.filter(fees, tx_types, currencies)

        error ->
          error
      end

    result_with_logging(result)
  end

  defp is_supported(%Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: %Transaction.Fee{}}}),
    do: {:error, :transaction_not_supported}

  defp is_supported(%Transaction.Recovered{}), do: :ok

  defp result_with_logging(result) do
    _ = Logger.debug(" resulted with #{inspect(result)}")
    result
  end
end
