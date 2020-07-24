# Copyright 2019-2020 OmiseGO Pte Ltd
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
defmodule Itest.ApiModel.IfeCompetitor do
  @moduledoc """
  The purpose of this module is to represent a specific API response as a struct and validates it's response
  """

  defstruct [
    :competing_input_index,
    :competing_proof,
    :competing_sig,
    :competing_tx_pos,
    :competing_txbytes,
    :in_flight_input_index,
    :in_flight_txbytes,
    :input_tx,
    :input_utxo_pos
  ]

  @type t() :: %__MODULE__{
          competing_input_index: integer(),
          competing_proof: binary(),
          competing_sig: binary(),
          competing_tx_pos: integer(),
          competing_txbytes: binary(),
          in_flight_input_index: integer(),
          in_flight_txbytes: binary(),
          input_tx: binary(),
          input_utxo_pos: integer()
        }

  def to_struct(attrs) do
    struct = struct(__MODULE__)

    result =
      Enum.reduce(Map.to_list(struct), struct, fn {k, _}, acc ->
        case Map.fetch(attrs, Atom.to_string(k)) do
          {:ok, v} -> %{acc | k => v}
          :error -> acc
        end
      end)

    true = is_valid(result)
    result
  end

  defp is_valid(struct) do
    is_integer(struct.competing_input_index) &&
      is_binary(struct.competing_proof) &&
      is_binary(struct.competing_sig) &&
      is_integer(struct.competing_tx_pos) &&
      is_binary(struct.competing_txbytes) &&
      is_integer(struct.in_flight_input_index) &&
      is_binary(struct.in_flight_txbytes) &&
      is_binary(struct.input_tx) &&
      is_integer(struct.input_utxo_pos)
  end
end
