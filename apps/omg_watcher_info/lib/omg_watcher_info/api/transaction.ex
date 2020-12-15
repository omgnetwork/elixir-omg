# Copyright 2019-2020 OMG Network Pte Ltd
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
    owner_inputs =
      order.owner
      |> DB.TxOutput.get_sorted_grouped_utxos(:desc)
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

  @doc """
  Converts parameter keyword list to a map before passing it to multi-clause "handle_merge/`1"
  """
  @spec merge(Keyword.t()) :: create_t()
  def merge(parameters) do
    parameters |> Map.new() |> handle_merge()
  end

  @spec handle_merge(map()) :: create_t()
  defp handle_merge(%{address: address, currency: currency}) do
    merge_inputs =
      address
      |> DB.TxOutput.get_sorted_grouped_utxos(:asc)
      |> Map.get(currency, [])

    case merge_inputs do
      [] ->
        {:error, :no_inputs_found}

      [_single_input] ->
        {:error, :single_input}

      inputs ->
        {:ok, TransactionCreator.generate_merge_transactions(inputs)}
    end
  end

  defp handle_merge(%{utxo_positions: utxo_positions}) do
    with {:ok, inputs} <- get_merge_inputs(utxo_positions),
         :ok <- no_duplicates(inputs),
         :ok <- single_owner(inputs),
         :ok <- single_currency(inputs) do
      {:ok, TransactionCreator.generate_merge_transactions(inputs)}
    end
  end

  defp get_utxos_count(currencies) do
    Enum.reduce(currencies, 0, fn {_, currency_inputs}, acc -> acc + length(currency_inputs) end)
  end

  defp create_transaction(utxos_count, inputs, _order) when utxos_count > Transaction.Payment.max_inputs() do
    transactions =
      inputs
      |> Enum.reduce([], fn {_, token_inputs}, acc ->
        merged_transactions =
          token_inputs
          |> TransactionCreator.generate_merge_transactions()
          |> Enum.reverse()

        merged_transactions ++ acc
      end)
      |> Enum.reverse()

    respond({:ok, transactions}, :intermediate)
  end

  defp create_transaction(_utxos_count, inputs, order) do
    inputs
    |> TransactionCreator.create(order)
    |> respond(:complete)
  end

  @spec get_merge_inputs(list()) :: {:ok, list()} | {:error, atom()}
  defp get_merge_inputs(utxo_positions) do
    Enum.reduce_while(utxo_positions, {:ok, []}, fn encoded_position, {:ok, acc} ->
      case encoded_position |> Utxo.Position.decode!() |> DB.TxOutput.get_by_position() do
        nil -> {:halt, {:error, :position_not_found}}
        input -> {:cont, {:ok, [input | acc]}}
      end
    end)
  end

  @spec no_duplicates(list()) :: :ok | {:error, :duplicate_input_positions}
  defp no_duplicates(inputs) do
    inputs
    |> Enum.uniq()
    |> length()
    |> case do
      n when n == length(inputs) -> :ok
      _ -> {:error, :duplicate_input_positions}
    end
  end

  @spec single_owner(list()) :: :ok | {:error, :multiple_input_owners}
  defp single_owner(inputs) do
    case inputs |> Enum.uniq_by(fn input -> input.owner end) |> length() do
      1 -> :ok
      _ -> {:error, :multiple_input_owners}
    end
  end

  @spec single_currency(list()) :: :ok | {:error, :multiple_currencies}
  defp single_currency(inputs) do
    case inputs |> Enum.uniq_by(fn input -> input.currency end) |> length() do
      1 -> :ok
      _ -> {:error, :multiple_currencies}
    end
  end

  defp respond({:ok, transactions}, result), do: {:ok, %{result: result, transactions: transactions}}
  defp respond(error, _), do: error
end
