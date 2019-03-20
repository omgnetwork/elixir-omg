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

defmodule OMG.Block do
  @moduledoc """
  Representation of an OMG network child chain block.
  """

  alias OMG.Crypto
  alias OMG.State.Transaction

  @transaction_merkle_tree_height 16
  @type block_hash_t() :: <<_::256>>

  defstruct [:transactions, :hash, :number]

  @type t() :: %__MODULE__{
          transactions: list(binary),
          hash: block_hash_t(),
          number: pos_integer()
        }

  @doc """
  Returns a Block from enumberable of transactions, at a certain child block number, along with a calculated merkle
  root hash
  """
  @spec hashed_txs_at(list(Transaction.Recovered.t()), non_neg_integer()) :: t()
  def hashed_txs_at(txs, blknum) do
    {txs_bytes, hashed_txs} =
      txs
      |> Enum.map(&get_data_per_tx/1)
      |> Enum.unzip()

    %__MODULE__{hash: merkle_hash(hashed_txs), transactions: txs_bytes, number: blknum}
  end

  @doc """
  Coerces the block struct to a format more in-line with the external API format
  """
  def to_api_format(%__MODULE__{number: blknum} = struct_block) do
    struct_block
    |> Map.from_struct()
    |> Map.delete(:number)
    |> Map.put(:blknum, blknum)
  end

  @doc """
  Calculates inclusion proof for the transaction in the block
  """
  @spec inclusion_proof(%__MODULE__{}, non_neg_integer()) :: binary()
  def inclusion_proof(%__MODULE__{transactions: transactions}, txindex) do
    {_, hashed_txs} =
      transactions
      |> Enum.map(&to_recovered_tx/1)
      |> Enum.map(&get_data_per_tx/1)
      |> Enum.unzip()

    create_tx_proof(hashed_txs, txindex)
  end

  # extracts the necessary data from a single transaction to include in a block and merkle hash
  # add more clauses to form blocks from other forms of transactions
  defp get_data_per_tx(%Transaction.Recovered{
         tx_hash: hash,
         signed_tx: %Transaction.Signed{signed_tx_bytes: bytes}
       }) do
    {bytes, hash}
  end

  defp to_recovered_tx(txbytes), do: Transaction.Recovered.recover_from!(txbytes)

  @default_leaf <<0>> |> List.duplicate(32) |> Enum.join() |> Crypto.hash()
  # Creates a Merkle proof that transaction under a given transaction index
  # is included in block consisting of hashed transactions
  @spec create_tx_proof(nonempty_list(binary()), non_neg_integer()) :: binary()
  defp create_tx_proof(hashed_txs, txindex),
    do:
      MerkleTree.new(hashed_txs,
        hash_function: &Crypto.hash/1,
        hash_leaves: false,
        height: @transaction_merkle_tree_height,
        default_data_block: @default_leaf
      )
      |> MerkleTree.Proof.prove(txindex)
      |> (& &1.hashes).()
      |> Enum.reverse()
      |> Enum.join()

  defp merkle_hash(hashed_txs),
    do:
      MerkleTree.new(hashed_txs,
        hash_function: &Crypto.hash/1,
        hash_leaves: false,
        height: @transaction_merkle_tree_height,
        default_data_block: @default_leaf
      ).root.value
end
