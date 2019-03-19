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

defmodule OMG.Utxo.Position do
  @moduledoc """
  Representation of a UTXO position in the child chain, providing encoding/decoding to/from format digestible in Eth
  """

  # these two offset constants are driven by the constants from the RootChain.sol contract
  @block_offset 1_000_000_000
  @transaction_offset 10_000

  alias OMG.Utxo
  require Utxo

  @type t() :: {
          :utxo_position,
          # blknum
          pos_integer,
          # txindex
          non_neg_integer,
          # oindex
          non_neg_integer
        }

  @spec encode(t()) :: pos_integer()
  def encode(Utxo.position(blknum, txindex, oindex)),
    do: blknum * @block_offset + txindex * @transaction_offset + oindex

  @spec decode(pos_integer()) :: t()
  def decode(encoded) when encoded >= @block_offset do
    blknum = div(encoded, @block_offset)
    txindex = encoded |> rem(@block_offset) |> div(@transaction_offset)
    oindex = rem(encoded, @transaction_offset)

    Utxo.position(blknum, txindex, oindex)
  end

  @spec non_zero?(t()) :: boolean()
  def non_zero?(Utxo.position(0, 0, 0)), do: false
  def non_zero?(Utxo.position(_, _, _)), do: true

  @spec to_db_key(t()) :: {pos_integer, non_neg_integer, non_neg_integer}
  def to_db_key(Utxo.position(blknum, txindex, oindex)), do: {blknum, txindex, oindex}

  @spec from_db_key({pos_integer, non_neg_integer, non_neg_integer}) :: t()
  def from_db_key({blknum, txindex, oindex}), do: Utxo.position(blknum, txindex, oindex)

  def blknum(Utxo.position(blknum, _, _)), do: blknum
  def txindex(Utxo.position(_, txindex, _)), do: txindex
  def oindex(Utxo.position(_, _, oindex)), do: oindex
end
