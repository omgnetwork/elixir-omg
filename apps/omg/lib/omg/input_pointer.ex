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

defmodule OMG.InputPointer do
  @moduledoc """
  `OMG.InputPointer` represent the data that's used to mention outputs that are intended 
  to be inputs to a transaction. Examples are UTXO positions or output id.
  (consisting of transaction hash and output index)
  """

  # TODO(achiurizo)
  # Do we really need this? How does this work with output type marker?
  @input_pointer_type_marker <<1>>

  @type utxo_pos_tuple() :: {
          :utxo_position,
          # blknum
          non_neg_integer,
          # txindex
          non_neg_integer,
          # oindex
          non_neg_integer
        }

  # This is the 'legacy' db format that the code is using to maintain backwards
  # compatibility.
  @type utxo_pos_db_tuple() :: {
          # blknum
          non_neg_integer,
          # txindex
          non_neg_integer,
          # oindex
          non_neg_integer
        }

  # This tuple is the format used to push into the DB(RocksDB)
  @type db_key_tuple() :: {
          :input_pointer,
          <<_::8>>,
          utxo_pos_db_tuple()
        }

  @position_too_low_error_tuple {:error, :encoded_utxo_position_too_low}
  @type position_too_low_error_tuple() :: {:error, :encoded_utxo_position_too_low}

  defstruct [:blknum, :txindex, :oindex]

  defguard is_position(blknum, txindex, oindex)
           when is_integer(blknum) and blknum >= 0 and
                  is_integer(txindex) and txindex >= 0 and
                  is_integer(oindex) and oindex >= 0

  @doc """
  Decode an integer into a utxo position tuple.

  ## Examples

    iex> OMG.InputPointer.decode!(1000020003)
    %OMG.InputPointer{blknum: 1, txindex: 2, oindex: 3}
  """
  @spec decode!(integer() | <<_::256>>) :: utxo_pos_tuple()
  def decode!(encoded) do
    {:ok, decoded} = decode(encoded)
    decoded
  end

  # TODO(achiurizo)
  # Do we really need an error tuple for a value too low?
  @doc """
  Decode an integer into a utxo position tuple.

  ## Examples

    # Returns an utxo position tuple from an integer
    iex> OMG.InputPointer.decode(1000020003)
    {:ok, %OMG.InputPointer{blknum: 1, txindex: 2, oindex: 3}}

    # Returns an utxo position tuple from a RLP-encodable binary.
    iex> OMG.InputPointer.decode(<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 119, 53, 187, 17>>)
    {:ok, %OMG.InputPointer{blknum: 2, txindex: 1, oindex: 1}}

    # Returns an error tuple if the value is too low
    iex> OMG.InputPointer.decode(-1)
    {:error, :encoded_utxo_position_too_low}
  """
  @spec decode(integer() | <<_::256>>) :: {:ok, utxo_pos_tuple()} | position_too_low_error_tuple()
  def decode(encoded) when is_binary(encoded) and byte_size(encoded) == 32,
    do: encoded |> :binary.decode_unsigned(:big) |> decode()

  def decode(encoded) when is_integer(encoded) and encoded <= 0,
    do: @position_too_low_error_tuple

  def decode(encoded) when is_integer(encoded) do
    %ExPlasma.Utxo{blknum: blknum, txindex: txindex, oindex: oindex} = ExPlasma.Utxo.new(encoded)
    {:ok, %OMG.InputPointer{blknum: blknum, txindex: txindex, oindex: oindex}}
  end

  @doc """
  Converts an input pointer db key into an utxo position tuple.

  ## Examples

    # Convert a DB key tuple(the one with the :input_pointer atom in front)
    iex> OMG.InputPointer.from_db_key({:input_pointer, <<1>>, {1, 2,3}})
    %OMG.InputPointer{blknum: 1, txindex: 2, oindex: 3}

    # Convert a legacy db key tuple for compatiblity(the _plain_ tuple)
    iex> OMG.InputPointer.from_db_key({1, 2, 3})
    %OMG.InputPointer{blknum: 1, txindex: 2, oindex: 3}
  """
  @spec from_db_key(db_key_tuple() | utxo_pos_db_tuple()) :: utxo_pos_tuple()
  def from_db_key({:input_pointer, @input_pointer_type_marker, db_value}), do: from_db_key(db_value)
  def from_db_key({blknum, txindex, oindex}), do: %OMG.InputPointer{blknum: blknum, txindex: txindex, oindex: oindex}

  @doc """
  Convert a utxo position tuple into a DB key tupble.

  ## Examples

    iex> OMG.InputPointer.to_db_key(%OMG.InputPointer{blknum: 1, txindex: 2, oindex: 3})
    {:input_pointer, <<1>>, {1, 2, 3}}
  """
  @spec to_db_key(utxo_pos_tuple()) :: db_key_tuple()
  def to_db_key(%OMG.InputPointer{blknum: blknum, txindex: txindex, oindex: oindex})
      when is_position(blknum, txindex, oindex),
      do: {:input_pointer, @input_pointer_type_marker, {blknum, txindex, oindex}}

  # TODO(achiurizo)
  #
  # refactor this method name. Just call it `to_rlp_data` or something shorter.
  @doc """
  Return the encoded input utxo position as a binary for RLP consumption.

  ## Examples

    iex> OMG.InputPointer.get_data_for_rlp(%OMG.InputPointer{blknum: 1, txindex: 2, oindex: 3})
    <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 59, 155, 24, 35>>
  """
  @spec get_data_for_rlp(utxo_pos_tuple()) :: binary()
  def get_data_for_rlp(%OMG.InputPointer{blknum: blknum, txindex: txindex, oindex: oindex})
      when is_position(blknum, txindex, oindex),
      do: ExPlasma.Utxo.to_input_list(%{blknum: blknum, txindex: txindex, oindex: oindex})
end
