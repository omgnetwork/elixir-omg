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
  alias OMG.Utxo

  @transaction_upper_limit 2 |> :math.pow(16) |> Kernel.trunc()

  @doc """
  Executes stateless validation of a submitted block:
  - Verifies that the number of transactions falls within the accepted range.
  - Verifies that transactions are correctly formed.
  - Verifies that there are no duplicate inputs at the block level.
  - Verifies that given Merkle root matches reconstructed Merkle root.
  """
  @spec stateless_validate(Block.t()) :: {:ok, boolean()} | {:error, atom()}
  def stateless_validate(submitted_block) do
    with :ok <- number_of_transactions_within_limit(submitted_block.transactions),
         {:ok, recovered_transactions} <- verify_transactions(submitted_block.transactions),
         {:ok, _inputs} <- verify_no_duplicate_inputs(recovered_transactions),
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

  @spec verify_transactions(transactions :: list(Transaction.Signed.txbytes())) ::
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

  @spec number_of_transactions_within_limit([Transaction.Signed.tx_bytes()]) ::
          :ok | {:error, atom()}
  defp number_of_transactions_within_limit(transactions) do
    case length(transactions) do
      # A block should at least have two transactions: a payment transaction and a fee transaction.
      n when n < 2 ->
        {:error, :transactions_below_block_minimum}

      n when n > @transaction_upper_limit ->
        {:error, :transactions_exceed_block_limit}

      _ ->
        :ok
    end
  end

  @spec verify_no_duplicate_inputs([Transaction.Recovered.t()]) :: {:ok, map()}
  defp(verify_no_duplicate_inputs(transactions)) do
    transactions
    |> Enum.reduce_while({:ok, %{}}, fn tx, {:ok, input_set} ->
      inputs =
        tx
        |> Map.get(:signed_tx)
        |> Map.get(:raw_tx)
        |> Map.get(:inputs)

      Enum.reduce_while(inputs, {:cont, {:ok, input_set}}, fn input, {:cont, {:ok, input_set}} ->
        input_position = Utxo.Position.encode(input)

        case Map.has_key?(input_set, input_position) do
          true -> {:halt, {:halt, {:error, :block_duplicate_inputs}}}
          false -> {:cont, {:cont, {:ok, Map.put(input_set, input_position, true)}}}
        end
      end)
    end)
  end
end
