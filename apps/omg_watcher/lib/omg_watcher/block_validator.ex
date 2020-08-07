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

  @doc """
  Executes stateless validation of a submitted block:
  - Verifies that transactions are correctly formed.
  - Verifies that given Merkle root matches reconstructed Merkle root.
  """
  @spec stateless_validate(Block.t()) :: {:ok, Block.t()} | {:error, atom()}
  def stateless_validate(submitted_block) do
    with {:ok, recovered_transactions} <- verify_transactions(submitted_block.transactions),
         {:ok, block} <- verify_merkle_root(submitted_block, recovered_transactions) do
      {:ok, block}
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

  @spec verify_transactions(transactions :: list(Transaction.Recovered.t())) ::
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
end
