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

defmodule OMG.Merkle do
  @moduledoc """
  Encapsulates all the interactions with the MerkleTree library.
  """

  alias OMG.Crypto

  @transaction_merkle_tree_height 16
  @default_leaf <<0>> |> List.duplicate(32) |> Enum.join() |> Crypto.hash()

  # Creates a Merkle proof that transaction under a given transaction index
  # is included in block consisting of hashed transactions
  @spec create_tx_proof(nonempty_list(binary()), non_neg_integer()) :: binary()
  def create_tx_proof(hashed_txs, txindex) do
    build(hashed_txs)
    |> prove(txindex)
    |> (& &1.hashes).()
    |> Enum.reverse()
    |> Enum.join()
  end

  @spec hash(nonempty_list(binary())) :: binary()
  def hash(hashed_txs) do
    MerkleTree.fast_root(hashed_txs,
      hash_function: &Crypto.hash/1,
      hash_leaves: false,
      height: @transaction_merkle_tree_height,
      default_data_block: @default_leaf
    )
  end

  defp build(hashed_txs) do
    MerkleTree.build(hashed_txs,
      hash_function: &Crypto.hash/1,
      hash_leaves: false,
      height: @transaction_merkle_tree_height,
      default_data_block: @default_leaf
    )
  end

  defp prove(hash, txindex) do
    MerkleTree.Proof.prove(hash, txindex)
  end
end
