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

# FIXME: should we have this ugly module, or just use Utxo.Position like protocols allow us to?
defmodule OMG.InputPointer.UtxoPosition do
  alias OMG.Utxo

  require Utxo

  defdelegate from_db_key(db_key), to: Utxo.Position

  def reconstruct([blknum, txindex, oindex]),
    do: Utxo.position(parse_int!(blknum), parse_int!(txindex), parse_int!(oindex))

  defp parse_int!(binary), do: :binary.decode_unsigned(binary, :big)
end

defimpl OMG.InputPointer.Protocol, for: Tuple do
  alias OMG.Utxo

  require Utxo

  # TODO: dry wrt. Application.fetch_env!(:omg, :input_pointer_types_modules)? Use `bimap` perhaps?
  @input_pointer_type_marker <<1>>

  @spec to_db_key(Utxo.Position.t()) :: {:input_pointer, binary(), tuple()}
  def to_db_key(Utxo.position(_, _, _) = utxo_pos),
    do: {:input_pointer, @input_pointer_type_marker, Utxo.Position.to_db_key(utxo_pos)}

  @spec get_data_for_rlp(Utxo.Position.t()) :: list()
  def get_data_for_rlp(Utxo.position(blknum, txindex, oindex)), do: [blknum, txindex, oindex]
end
