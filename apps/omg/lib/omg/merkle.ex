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

defmodule OMG.Merkle do
  @moduledoc """
  Encapsulates all the interactions with the MerkleTree library.
  """

  alias OMG.Crypto

  @transaction_merkle_tree_height 16
  @default_leaf <<0::256>>

  # Creates a Merkle proof that transaction under a given transaction index
  # is included in block consisting of hashed transactions
  @spec create_tx_proof(list(String.t()), non_neg_integer()) :: binary()
  def create_tx_proof(txs_bytes, txindex) do
    build(txs_bytes)
    |> prove(txindex)
    |> Enum.reverse()
    |> Enum.join()
  end

  @spec hash(list(String.t())) :: binary()
  def hash(hashed_txs) do
    MerkleTree.fast_root(hashed_txs,
      hash_function: &Crypto.hash/1,
      height: @transaction_merkle_tree_height,
      default_data_block: @default_leaf
    )
  end

  defp build(txs_bytes) do
    MerkleTree.build(txs_bytes,
      hash_function: &Crypto.hash/1,
      height: @transaction_merkle_tree_height,
      default_data_block: @default_leaf
    )
  end

  defp prove(tx_bytes, txindex) do
    MerkleTree.Proof.prove(tx_bytes, txindex)
  end
end
