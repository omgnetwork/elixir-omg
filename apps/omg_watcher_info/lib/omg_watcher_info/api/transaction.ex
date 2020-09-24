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

defmodule OMG.WatcherInfo.API.Transaction do
  @moduledoc """
  Module provides API for transactions
  """

  alias OMG.State.Transaction
  alias OMG.Utils.Paginator
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.HttpRPC.Client
  alias OMG.WatcherInfo.Transaction, as: TransactionCreator

  require Utxo
  require Transaction.Payment

  @default_transactions_limit 200

  @type create_t() ::
          {:ok,
           %{
             result: :complete | :intermediate,
             transactions: nonempty_list(TransactionCreator.transaction_with_typed_data_t())
           }}
          | {:error, :too_many_outputs}
          | {:error, :empty_transaction}
          | {:error, {:insufficient_funds, list(map())}}

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
  @spec get_transactions(Keyword.t()) :: Paginator.t(%DB.Transaction{})
  def get_transactions(constraints) do
    paginator = Paginator.from_constraints(constraints, @default_transactions_limit)

    constraints
    |> Keyword.drop([:limit, :page])
    |> DB.Transaction.get_by_filters(paginator)
  end

  @doc """
  Passes the signed transaction to the child chain.

  Caution: This function is unaware of the child chain's security status, e.g.:

  * Watcher is fully synced,
  * all operator blocks have been verified,
  * transaction doesn't spend funds not yet mined
  * etc...
  """
  @spec submit(Transaction.Signed.t()) :: Client.response_t() | {:error, atom()}
  def submit(%Transaction.Signed{} = signed_tx) do
    url = Application.get_env(:omg_watcher_info, :child_chain_url)

    signed_tx
    |> Transaction.Signed.encode()
    |> Client.submit(url)
  end

  @doc """
  Given order finds spender's inputs sufficient to perform a payment.
  If also provided with receiver's address, creates and encodes a transaction.
  """
  @spec create(TransactionCreator.order_t()) :: create_t()
  def create(order) do
    owner_inputs = order.owner
      |> DB.TxOutput.get_sorted_grouped_utxos()
      |> TransactionCreator.select_inputs(order)

    case owner_inputs do
      {:ok, inputs} ->
        inputs
        |> get_utxos_count()
        |> create_transaction(inputs, order)

      err ->
        err
    end
  end

  defp get_utxos_count(currencies) do
    Enum.reduce(currencies, 0, fn {_, currency_inputs}, acc -> acc + length(currency_inputs) end)
  end

  defp create_transaction(utxos_count, inputs, _order) when utxos_count > Transaction.Payment.max_inputs() do
    transactions = Enum.reduce(inputs, [], fn {_, token_inputs}, acc ->
        TransactionCreator.generate_merge_transactions(token_inputs) ++ acc
      end)

    respond({:ok, transactions}, :intermediate)
  end

  defp create_transaction(_utxos_count, inputs, order) do
    inputs
    |> TransactionCreator.create(order)
    |> respond(:complete)
  end

  defp respond({:ok, transactions}, result), do: {:ok, %{result: result, transactions: transactions}}
  defp respond(error, _), do: error
end
