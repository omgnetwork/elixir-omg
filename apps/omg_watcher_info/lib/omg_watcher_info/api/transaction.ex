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

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.TypedDataHash
  alias OMG.Utils.Paginator
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.HttpRPC.Client
  alias OMG.WatcherInfo.Transaction, as: TransactionCreator

  require Utxo
  require Transaction.Payment

  @default_transactions_limit 200
  @type create_t() :: TransactionCreator.create_t() | {:error, {:insufficient_funds, list(map())}}

  @type transaction_t() :: %{
          inputs: nonempty_list(%DB.TxOutput{}),
          outputs: nonempty_list(TransactionCreator.payment_t()),
          fee: TransactionCreator.fee_t(),
          txbytes: Transaction.tx_bytes() | nil,
          metadata: Transaction.metadata(),
          sign_hash: Crypto.hash_t() | nil,
          typed_data: TypedDataHash.Types.typedDataSignRequest_t()
        }

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
    case order.owner
         |> DB.TxOutput.get_sorted_grouped_utxos(:desc)
         |> TransactionCreator.select_inputs(order) do
      {:ok, inputs} ->
        inputs
        |> get_utxos_count()
        |> create_transaction(inputs, order)

      err ->
        err
    end
  end

  @spec merge(map()) :: create_t()
  def merge(%{address: address, currency: currency}) do
    merge_inputs =
      address
      |> DB.TxOutput.get_sorted_grouped_utxos(:asc)
      |> Map.get(currency, [])

    case merge_inputs do
      [] ->
        {:error, :no_inputs_found}

      [_single_input] ->
        {:error, :no_possible_merge_combination}

      inputs ->
        {:ok, TransactionCreator.generate_merge_transactions(inputs)}
    end
  end

  def merge(%{utxo_positions: utxo_positions}) do
    with {:ok, _} <- no_duplicate_positions(utxo_positions),
         {:ok, inputs} <- get_merge_inputs(utxo_positions),
         {:ok, transactions} <- generate_merge_transactions_by_currency(inputs) do
      flattened_transaction_list = List.flatten(transactions)

      if Enum.empty?(flattened_transaction_list) do
        # Return an error instead of empty list if user passes one position per currency.
        {:error, :no_possible_merge_combination}
      else
        {:ok, flattened_transaction_list}
      end
    end
  end

  defp generate_merge_transactions_by_currency(inputs) do
    inputs
    |> Enum.group_by(fn input -> input.currency end)
    |> Enum.reduce_while({:ok, []}, fn {_ccy, inputs}, {:ok, acc} ->
      case single_owner(inputs) do
        :ok ->
          transactions = TransactionCreator.generate_merge_transactions(inputs)
          {:cont, {:ok, [transactions | acc]}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end

  defp get_utxos_count(inputs) do
    inputs
    |> Enum.map(fn {_, utxos} -> utxos end)
    |> List.flatten()
    |> Enum.count()
  end

  defp create_transaction(utxos_count, inputs, _order) when utxos_count > Transaction.Payment.max_inputs() do
    inputs
    |> TransactionCreator.generate_merge_transactions()
    |> respond(:intermediate)
  end

  defp create_transaction(_utxos_count, inputs, order) do
    inputs
    |> TransactionCreator.create(order)
    |> respond(:complete)
  end

  defp get_merge_inputs(utxo_positions) do
    Enum.reduce_while(utxo_positions, {:ok, []}, fn encoded_position, {:ok, acc} ->
      case encoded_position |> Utxo.Position.decode!() |> DB.TxOutput.get_by_position() do
        nil -> {:halt, {:error, :position_not_found}}
        input -> {:cont, {:ok, [input | acc]}}
      end
    end)
  end

  defp no_duplicate_positions(positions_list) do
    Enum.reduce_while(positions_list, {:ok, %{}}, fn position, {:ok, acc} ->
      case Map.has_key?(acc, position) do
        true -> {:halt, {:error, :duplicate_input_positions}}
        false -> {:cont, {:ok, Map.put(acc, position, true)}}
      end
    end)
  end

  defp single_owner(inputs) do
    case inputs |> Enum.uniq_by(fn input -> input.owner end) |> length() do
      1 -> :ok
      _ -> {:error, :multiple_input_owners}
    end
  end

  defp respond({:ok, transaction}, result), do: {:ok, %{result: result, transactions: [transaction]}}

  defp respond(transactions, result) when is_list(transactions),
    do: {:ok, %{result: result, transactions: transactions}}
end
