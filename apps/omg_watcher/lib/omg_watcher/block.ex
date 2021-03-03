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

defmodule OMG.Watcher.Block do
  @moduledoc """
  Representation of an OMG network child chain block.
  """

  alias OMG.Watcher.Merkle
  alias OMG.Watcher.State.Transaction

  @type block_hash_t() :: <<_::256>>

  defstruct [:transactions, :hash, :number]

  @type t() :: %__MODULE__{
          transactions: list(Transaction.Signed.tx_bytes()),
          hash: block_hash_t(),
          number: pos_integer()
        }

  @type db_t() :: %{
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
    signed_txs_bytes = Enum.map(txs, & &1.signed_tx_bytes)
    txs_bytes = Enum.map(txs, &Transaction.raw_txbytes/1)

    %__MODULE__{hash: Merkle.hash(txs_bytes), transactions: signed_txs_bytes, number: blknum}
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

  # NOTE: we have no migrations, so we handle data compatibility here (make_db_update/1 and from_db_kv/1), OMG-421
  def to_db_value(%__MODULE__{transactions: transactions, hash: hash, number: number})
      when is_list(transactions) and is_binary(hash) and is_integer(number) do
    %{transactions: transactions, hash: hash, number: number}
  end

  def from_db_value(%{transactions: transactions, hash: hash, number: number})
      when is_list(transactions) and is_binary(hash) and is_integer(number) do
    value = %{transactions: transactions, hash: hash, number: number}
    struct!(__MODULE__, value)
  end

  @doc """
  Calculates inclusion proof for the transaction in the block
  """
  @spec inclusion_proof(t() | list(Transaction.Signed.tx_bytes()), non_neg_integer()) :: binary()
  def inclusion_proof(transactions, txindex) when is_list(transactions) do
    txs_bytes =
      transactions
      |> Enum.map(&Transaction.Signed.decode!/1)
      |> Enum.map(&Transaction.raw_txbytes/1)

    Merkle.create_tx_proof(txs_bytes, txindex)
  end

  def inclusion_proof(%__MODULE__{transactions: transactions}, txindex), do: inclusion_proof(transactions, txindex)
end
