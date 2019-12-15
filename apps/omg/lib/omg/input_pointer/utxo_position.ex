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

defmodule OMG.InputPointer.UtxoPosition do
  @moduledoc """
  Represents the UTXO position interpeted as an implementation of an input pointer type
  """

  alias OMG.Utxo

  require Utxo

  defdelegate from_db_key(db_key), to: Utxo.Position

  def reconstruct(binary_input) when is_binary(binary_input),
    do: binary_input |> ensure_32bytes! |> :binary.decode_unsigned(:big) |> Utxo.Position.decode!()

  defp ensure_32bytes!(binary_input) when byte_size(binary_input) == 32, do: binary_input
end

defimpl OMG.InputPointer.Protocol, for: Tuple do
  alias OMG.Utxo

  require Utxo

  # TODO: dry wrt. Application.fetch_env!(:omg, :input_pointer_types_modules)? Use `bimap` perhaps?
  @input_pointer_type_marker <<1>>

  @spec to_db_key(Utxo.Position.t()) :: {:input_pointer, binary(), Utxo.Position.db_t()}
  def to_db_key(Utxo.position(_, _, _) = utxo_pos),
    do: {:input_pointer, @input_pointer_type_marker, Utxo.Position.to_db_key(utxo_pos)}

  @spec get_data_for_rlp(tuple()) :: binary()
  def get_data_for_rlp({:utxo_position, blknum, txindex, oindex}),
    do: ExPlasma.Utxo.to_input_list(%{blknum: blknum, txindex: txindex, oindex: oindex})
end
