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
  `OMG.InputPointer` and `OMG.InputPointer` represent the data that's used to mention outputs that are intended
  to be inputs to a transaction. Examples are UTXO positions or output id (consisting of transaction hash and output
  index)

  This module specificially dispatches generic calls to the various specific types
  """

  alias OMG.Utxo
  require Utxo

  @input_pointer_types_modules OMG.WireFormatTypes.input_pointer_type_modules()

  def from_db_key({:input_pointer, output_type, db_value}),
    do: @input_pointer_types_modules[output_type].from_db_key(db_value)

  # default clause for backwards compatibility
  def from_db_key(db_value), do: OMG.InputPointer.UtxoPosition.from_db_key(db_value)

  @input_pointer_output_type OMG.WireFormatTypes.input_pointer_type_for(:input_pointer_utxo_position)

  @spec to_db_key(Utxo.Position.t()) :: {:input_pointer, pos_integer(), Utxo.Position.db_t()}
  def to_db_key(Utxo.position(_, _, _) = utxo_pos),
    do: {:input_pointer, @input_pointer_output_type, Utxo.Position.to_db_key(utxo_pos)}

  @spec get_data_for_rlp(Utxo.Position.t()) :: binary()
  def get_data_for_rlp(Utxo.position(_, _, _) = utxo_pos),
    do: utxo_pos |> Utxo.Position.encode() |> :binary.encode_unsigned(:big) |> pad()

  defp pad(unpadded) do
    padding_bits = (32 - byte_size(unpadded)) * 8
    <<0::size(padding_bits)>> <> unpadded
  end
end
