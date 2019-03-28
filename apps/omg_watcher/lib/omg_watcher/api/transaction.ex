# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.API.Transaction do
  @moduledoc """
  Module provides API for transactions
  """

  alias OMG.RPC.Client
  alias OMG.Utxo
  alias OMG.Watcher.DB
  alias OMG.Watcher.UtxoSelection

  require Utxo

  @default_transactions_limit 200

  @doc """
  Retrieves a specific transaction by id
  """
  @spec get(binary()) :: {:ok, %DB.Transaction{}} | {:error, :transaction_not_found}
  def get(transaction_id) do
    if transaction = DB.Transaction.get(transaction_id),
      do: {:ok, transaction},
      else: {:error, :transaction_not_found}
  end

  @doc """
  Retrieves a list of transactions that:
   - (optionally) a given address is involved as input or output owner.
   - (optionally) belong to a given child block number

  Length of the list is limited by `limit` argument
  """
  @spec get_transactions(Keyword.t()) :: list(%DB.Transaction{})
  def get_transactions(constrains) do
    # TODO: implement pagination. Defend against fetching huge dataset.
    constrains =
      constrains
      |> Keyword.update(:limit, @default_transactions_limit, &min(&1, @default_transactions_limit))

    DB.Transaction.get_by_filters(constrains)
  end

  @doc """
  Passes signed transaction to the child chain only if it's secure, e.g.
  * Watcher is fully synced,
  * all operator blocks have been verified,
  * transaction doesn't spend funds not yet mined
  * etc...

  Note: No validation for now, just passes given tx to the child chain. See: OMG-410
  """
  @spec submit(binary()) :: Client.response_t()
  def(submit(txbytes)) do
    Client.submit(txbytes)
  end

  @doc """
  Given order finds spender's inputs sufficient to perform a payment.
  If also provided with receiver's address, creates and encodes a transaction.
  """
  @spec create(UtxoSelection.order_t()) :: UtxoSelection.advice_t()
  def create(order) do
    utxos = DB.TxOutput.get_sorted_grouped_utxos(order.owner)
    UtxoSelection.create_advice(utxos, order)
  end
end
