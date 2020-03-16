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
defmodule Itest.ApiModel.IfeOutputChallenge do
  @moduledoc """
  The purpose of this module is to represent a specific API response as a struct and validates it's response
  """

  defstruct [
    :in_flight_txbytes,
    :in_flight_output_pos,
    :spending_txbytes,
    :spending_input_index,
    :spending_sig,
    :in_flight_proof
  ]

  @type t() :: %__MODULE__{
          in_flight_txbytes: binary(),
          spending_txbytes: binary(),
          spending_input_index: non_neg_integer(),
          spending_sig: binary(),
          in_flight_proof: binary()
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
    is_binary(struct.in_flight_txbytes) &&
      is_integer(struct.in_flight_output_pos) &&
      is_binary(struct.spending_txbytes) &&
      is_integer(struct.spending_input_index) &&
      is_binary(struct.spending_sig) &&
      is_binary(struct.in_flight_proof)
  end
end
