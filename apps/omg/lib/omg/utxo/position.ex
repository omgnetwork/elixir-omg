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
  @input_pointer_output_type 1

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
    do: ExPlasma.Utxo.pos(%{blknum: blknum, txindex: txindex, oindex: oindex})

  @spec decode!(number()) :: t()
  def decode!(encoded) do
    {:ok, decoded} = decode(encoded)
    decoded
  end

  @spec decode(binary()) :: {:ok, t()} | {:error, :encoded_utxo_position_too_low}
  def decode(encoded) when is_number(encoded) and encoded <= 0, do: {:error, :encoded_utxo_position_too_low}
  def decode(encoded) when is_integer(encoded) and encoded > 0, do: do_decode(encoded)
  def decode(encoded) when is_binary(encoded) and byte_size(encoded) == 32, do: do_decode(encoded)

  defp do_decode(encoded) do
    utxo = ExPlasma.Utxo.new(encoded)
    {:ok, Utxo.position(utxo.blknum, utxo.txindex, utxo.oindex)}
  end

  @spec to_db_key(Utxo.Position.t()) :: {:input_pointer, pos_integer(), Utxo.Position.db_t()}
  def to_input_db_key(Utxo.position(blknum, txindex, oindex)) when is_position(blknum, txindex, oindex),
    do: {:input_pointer, @input_pointer_output_type, {blknum, txindex, oindex}}

  @spec to_db_key(t()) :: db_t()
  def to_db_key(Utxo.position(blknum, txindex, oindex)) when is_position(blknum, txindex, oindex),
    do: {blknum, txindex, oindex}

  def from_db_key({:input_pointer, _output_type, db_value}), do: from_db_key(db_value)

  @spec from_db_key(db_t()) :: t()
  def from_db_key({blknum, txindex, oindex}) when is_position(blknum, txindex, oindex),
    do: Utxo.position(blknum, txindex, oindex)

  @doc """
  Based on the contract parameters determines whether UTXO position provided was created by a deposit
  """
  @spec is_deposit?(__MODULE__.t()) :: boolean()
  def is_deposit?(Utxo.position(blknum, txindex, oindex)) when is_position(blknum, txindex, oindex) do
    {:ok, interval} = OMG.Eth.RootChain.get_child_block_interval()
    rem(blknum, interval) != 0
  end


  @spec get_data_for_rlp(Utxo.Position.t()) :: binary()
  def get_data_for_rlp(Utxo.position(blknum, txindex, oindex)) do
    utxo = %ExPlasma.Utxo{blknum: blknum, txindex: txindex, oindex: oindex}
    ExPlasma.Utxo.to_rlp(utxo)
  end
end
