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

defmodule OMG.Utxo.Position do
  @moduledoc """
  Representation of a UTXO position in the child chain, providing encoding/decoding to/from formats digestible in `Eth`
  and in the `OMG.DB`
  """

  # these two offset constants are driven by the constants from the RootChain.sol contract
  @block_offset 1_000_000_000
  @transaction_offset 10_000

  alias OMG.Utxo
  require Utxo

  import Utxo, only: [is_position: 3]

  @type t() :: {
          :utxo_position,
          # blknum
          non_neg_integer,
          # txindex
          non_neg_integer,
          # oindex
          non_neg_integer
        }

  @type db_t() :: {non_neg_integer, non_neg_integer, non_neg_integer}

  @spec encode(t()) :: non_neg_integer()
  def encode(Utxo.position(blknum, txindex, oindex)) when is_position(blknum, txindex, oindex),
    do: blknum * @block_offset + txindex * @transaction_offset + oindex

  @spec decode!(number()) :: t()
  def decode!(encoded) do
    {:ok, decoded} = decode(encoded)
    decoded
  end

  @spec decode(number()) :: {:ok, t()} | {:error, :encoded_utxo_position_too_low}
  def decode(encoded) when is_integer(encoded) and encoded > 0 do
    {blknum, txindex, oindex} = get_position(encoded)
    {:ok, Utxo.position(blknum, txindex, oindex)}
  end

  def decode(encoded) when is_number(encoded), do: {:error, :encoded_utxo_position_too_low}

  @spec to_db_key(t()) :: db_t()
  def to_db_key(Utxo.position(blknum, txindex, oindex)) when is_position(blknum, txindex, oindex),
    do: {blknum, txindex, oindex}

  @spec from_db_key(db_t()) :: t()
  def from_db_key({blknum, txindex, oindex}) when is_position(blknum, txindex, oindex),
    do: Utxo.position(blknum, txindex, oindex)

  def blknum(Utxo.position(blknum, _, _)), do: blknum
  def txindex(Utxo.position(_, txindex, _)), do: txindex
  def oindex(Utxo.position(_, _, oindex)), do: oindex

  @spec get_position(pos_integer()) :: {non_neg_integer, non_neg_integer, non_neg_integer}
  defp get_position(encoded) when is_integer(encoded) and encoded > 0 do
    blknum = div(encoded, @block_offset)
    txindex = encoded |> rem(@block_offset) |> div(@transaction_offset)
    oindex = rem(encoded, @transaction_offset)
    {blknum, txindex, oindex}
  end

  @doc """
  Based on the contract parameters determines whether UTXO position provided was created by a deposit
  """
  @spec is_deposit?(__MODULE__.t()) :: boolean()
  def is_deposit?(Utxo.position(blknum, txindex, oindex)) when is_position(blknum, txindex, oindex) do
    {:ok, interval} = OMG.Eth.RootChain.get_child_block_interval()
    rem(blknum, interval) != 0
  end
end
