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

defmodule OMG.Watcher.Utxo.Position do
  @moduledoc """
  Representation of a UTXO position in the child chain, providing encoding/decoding to/from formats digestible in `Eth`
  and in the `OMG.DB`
  """

  # these two offset constants are driven by the constants from the RootChain.sol contract
  @input_pointer_output_type 1
  alias ExPlasma.Output, as: ExPlasmaOutput
  alias ExPlasma.Output.Position, as: ExPlasmaPosition
  alias OMG.Watcher.Utxo
  require Utxo

  @type t() :: {
          :utxo_position,
          # blknum
          non_neg_integer(),
          # txindex
          non_neg_integer(),
          # oindex
          non_neg_integer()
        }

  @type db_t() :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}

  @type input_db_key_t() :: {:input_pointer, pos_integer(), db_t()}

  defguardp is_position(blknum, txindex, oindex)
            when is_integer(blknum) and blknum >= 0 and
                   is_integer(txindex) and txindex >= 0 and
                   is_integer(oindex) and oindex >= 0

  @doc """
  Encode an input utxo position into an integer value.

  ## Examples

      iex> utxo_pos = {:utxo_position, 4, 5, 1}
      iex> OMG.Watcher.Utxo.Position.encode(utxo_pos)
      4_000_050_001
  """
  @spec encode(t()) :: pos_integer()
  def encode(Utxo.position(blknum, txindex, oindex)) when is_position(blknum, txindex, oindex) do
    ExPlasmaPosition.pos(%{blknum: blknum, txindex: txindex, oindex: oindex})
  end

  @doc """
  Decode an integer or binary into a utxo position tuple.

  ## Examples

      # Decodes an integer encoded utxo position.
      iex> OMG.Watcher.Utxo.Position.decode!(4_000_050_001)
      {:utxo_position, 4, 5, 1}

      # Decode a binary encoded utxo position.
      iex> encoded_pos = <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 238, 107, 235, 81>>
      iex> OMG.Watcher.Utxo.Position.decode!(encoded_pos)
      {:utxo_position, 4, 5, 1}
  """
  @spec decode!(binary()) :: t()
  def decode!(encoded) do
    {:ok, decoded} = decode(encoded)
    decoded
  end

  @doc """
  Decode an integer or binary into a utxo position tuple.

  ## Examples

      # Decode an integer encoded utxo position.
      iex> OMG.Watcher.Utxo.Position.decode(4_000_050_001)
      {:ok, {:utxo_position, 4, 5, 1}}

      # Returns an error if the value is too low.
      iex> OMG.Watcher.Utxo.Position.decode(0)
      {:error, :encoded_utxo_position_too_low}

      iex> OMG.Watcher.Utxo.Position.decode(-1)
      {:error, :encoded_utxo_position_too_low}

      # Decode a binary encoded utxo position.
      iex> encoded_pos = <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 238, 107, 235, 81>>
      iex> OMG.Watcher.Utxo.Position.decode(encoded_pos)
      {:ok, {:utxo_position, 4, 5, 1}}
  """
  @spec decode(binary()) :: {:ok, t()} | {:error, :encoded_utxo_position_too_low | {:blknum, :exceeds_maximum}}
  def decode(encoded) when is_number(encoded) and encoded <= 0, do: {:error, :encoded_utxo_position_too_low}
  def decode(encoded) when is_integer(encoded) and encoded > 0, do: do_decode(encoded)
  def decode(encoded) when is_binary(encoded) and byte_size(encoded) == 32, do: do_decode(encoded)

  # TODO(achiurizo)
  # Refactor to_input_db_key/1 and to_db_key/1. Doing this because
  # this was merged from a previous module where one code path still wants the 3 item tuple.
  @doc """
  Convert a utxo position into the input db key tuple.

  ## Examples

      iex> utxo_pos = {:utxo_position, 1, 2, 3}
      iex> OMG.Watcher.Utxo.Position.to_input_db_key(utxo_pos)
      {:input_pointer, 1, {1, 2, 3}}
  """
  @spec to_input_db_key(t()) :: {:input_pointer, unquote(@input_pointer_output_type), db_t()}
  def to_input_db_key(Utxo.position(blknum, txindex, oindex)) when is_position(blknum, txindex, oindex),
    do: {:input_pointer, @input_pointer_output_type, {blknum, txindex, oindex}}

  @doc """
  Convert a utxo position into the db key tuple. (legacy?)

  ## Examples

      iex> utxo_pos = {:utxo_position, 1, 2, 3}
      iex> OMG.Watcher.Utxo.Position.to_db_key(utxo_pos)
      {1, 2, 3}
  """
  @spec to_db_key(t()) :: db_t()
  def to_db_key(Utxo.position(blknum, txindex, oindex)), do: {blknum, txindex, oindex}

  # TODO(achiurizo)
  # Refactor so we only have one db key type.
  @doc """
  Convert an input db key tuple into a utxo position.

  ## Examples

      # Convert an input db key tuple into a utxo position.
      iex> input_db_key = {:input_pointer, 1, {1, 2, 3}}
      iex> OMG.Watcher.Utxo.Position.from_db_key(input_db_key)
      {:utxo_position, 1, 2, 3}

      # Convert a 'legacy' db key tuple into a utxo position
      iex> legacy_input_db_key = {1, 2, 3}
      iex> OMG.Watcher.Utxo.Position.from_db_key(legacy_input_db_key)
      {:utxo_position, 1, 2, 3}
  """
  @spec from_db_key(db_t() | input_db_key_t()) :: t()
  def from_db_key({:input_pointer, _output_type, db_value}), do: from_db_key(db_value)

  def from_db_key({blknum, txindex, oindex}) when is_position(blknum, txindex, oindex),
    do: Utxo.position(blknum, txindex, oindex)

  # TODO(achiurizo)
  # better name for this function, like to_rlp/1.
  @doc """
  Returns the rlp-encodable data for the given utxo position.

  ## Examples

      iex> utxo_pos = {:utxo_position, 1, 2, 3}
      iex> OMG.Watcher.Utxo.Position.get_data_for_rlp(utxo_pos)
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 59, 155, 24, 35>>
  """
  @spec get_data_for_rlp(t()) :: binary()
  def get_data_for_rlp(Utxo.position(blknum, txindex, oindex)) do
    utxo = ExPlasmaPosition.new(blknum, txindex, oindex)
    ExPlasmaPosition.to_rlp(utxo)
  end

  defp do_decode(encoded) when is_binary(encoded) do
    {:ok, %ExPlasmaOutput{output_id: %{blknum: blknum, txindex: txindex, oindex: oindex}}} =
      ExPlasmaOutput.decode_id(encoded)

    {:ok, Utxo.position(blknum, txindex, oindex)}
  end

  defp do_decode(encoded) when is_integer(encoded) do
    {:ok, utxo} = ExPlasmaPosition.to_map(encoded)
    {:ok, Utxo.position(utxo.blknum, utxo.txindex, utxo.oindex)}
  end
end
