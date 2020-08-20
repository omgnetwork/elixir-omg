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

defmodule OMG.Watcher.BlockValidator do
  @moduledoc """
  Operations related to block validation.
  """

  alias OMG.Block
  alias OMG.Merkle
  alias OMG.State.Transaction
  alias OMG.Utxo.Position

  @transaction_upper_limit 2 |> :math.pow(16) |> Kernel.trunc()

  @doc """
  Executes stateless validation of a submitted block:
  - Verifies that the number of transactions falls within the accepted range.
  - Verifies that (payment and fee) transactions  are correctly formed.
  - Verifies that there are no duplicate inputs at the block level.
  - Verifies that given Merkle root matches reconstructed Merkle root.
  - Verifies that fee transactions are correctly placed and unique per currency.
  """
  @spec stateless_validate(Block.t()) :: {:ok, boolean()} | {:error, atom()}
  def stateless_validate(submitted_block) do
    with :ok <- number_of_transactions_within_limit(submitted_block.transactions),
         {:ok, recovered_transactions} <- verify_transactions(submitted_block.transactions),
         {:ok, _fee_transactions} <- verify_fee_transactions(recovered_transactions),
         {:ok, _inputs} <- verify_no_duplicate_inputs(recovered_transactions, %{}),
         {:ok, _block} <- verify_merkle_root(submitted_block, recovered_transactions) do
      {:ok, true}
    end
  end

  @spec verify_merkle_root(Block.t(), list(Transaction.Recovered.t())) ::
          {:ok, Block.t()} | {:error, :mismatched_merkle_root}
  defp verify_merkle_root(block, transactions) do
    reconstructed_merkle_hash =
      transactions
      |> Enum.map(&Transaction.raw_txbytes/1)
      |> Merkle.hash()

    case block.hash do
      ^reconstructed_merkle_hash -> {:ok, block}
      _ -> {:error, :invalid_merkle_root}
    end
  end

  @spec verify_transactions(transactions :: list(Transaction.Signed.tx_bytes())) ::
          {:ok, list(Transaction.Recovered.t())}
          | {:error, Transaction.Recovered.recover_tx_error()}
  defp verify_transactions(transactions) do
    transactions
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, []}, fn tx, {:ok, already_recovered} ->
      case Transaction.Recovered.recover_from(tx) do
        {:ok, recovered} ->
          {:cont, {:ok, [recovered | already_recovered]}}

        error ->
          {:halt, error}
      end
    end)
  end

  @spec number_of_transactions_within_limit([Transaction.Signed.tx_bytes()]) :: :ok | {:error, atom()}
  defp number_of_transactions_within_limit(transactions) when length(transactions) == 0, do: {:error, :empty_block}

  defp number_of_transactions_within_limit(transactions) when length(transactions) > @transaction_upper_limit do
    {:error, :transactions_exceed_block_limit}
  end

  defp number_of_transactions_within_limit(_transactions), do: :ok

  @spec verify_no_duplicate_inputs([Transaction.Recovered.t()], map()) :: {:ok, map()}
  defp verify_no_duplicate_inputs([], input_set), do: {:ok, input_set}

  defp verify_no_duplicate_inputs([transaction | rest], input_set) do
    current_input_positions = transaction |> Transaction.get_inputs() |> Enum.map(&Position.encode/1)

    current_input_positions
    |> Enum.any?(fn input_position -> Map.has_key?(input_set, input_position) end)
    |> case do
      true ->
        {:error, :block_duplicate_inputs}

      false ->
        new_input_set = current_input_positions |> Map.new(fn pos -> {pos, true} end) |> Map.merge(input_set)
        verify_no_duplicate_inputs(rest, new_input_set)
    end
  end

  @spec verify_fee_transactions([Transaction.Recovered.t()]) :: {:ok, [Transaction.Recovered.t()]} | {:error, atom()}
  defp verify_fee_transactions(transactions) do
    identified_fee_transactions = Enum.filter(transactions, &is_fee/1)

    with :ok <- expected_index(transactions, identified_fee_transactions),
         :ok <- unique_fee_transaction_per_currency(identified_fee_transactions) do
      {:ok, identified_fee_transactions}
    end
  end

  @spec expected_index([Transaction.Recovered.t()], [Transaction.Recovered.t()]) :: :ok | {:error, atom()}
  defp expected_index(transactions, identified_fee_transactions) do
    number_of_fee_txs = length(identified_fee_transactions)
    tail = Enum.slice(transactions, -number_of_fee_txs, number_of_fee_txs)

    case identified_fee_transactions do
      ^tail -> :ok
      _ -> {:error, :unexpected_transaction_type_at_fee_index}
    end
  end

  @spec unique_fee_transaction_per_currency([Transaction.Recovered.t()]) :: :ok | {:error, atom()}
  defp unique_fee_transaction_per_currency(identified_fee_transactions) do
    identified_fee_transactions
    |> Enum.uniq_by(fn fee_transaction -> fee_transaction |> get_fee_output() |> Map.get(:currency) end)
    |> case do
      ^identified_fee_transactions -> :ok
      _ -> {:error, :duplicate_fee_transaction_for_ccy}
    end
  end

  defp is_fee(%Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: %Transaction.Fee{}}}),
    do: true

  defp is_fee(_), do: false

  defp get_fee_output(fee_transaction) do
    fee_transaction |> Transaction.get_outputs() |> Enum.at(0)
  end
end
