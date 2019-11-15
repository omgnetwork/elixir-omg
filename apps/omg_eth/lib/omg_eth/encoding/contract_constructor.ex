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

defmodule OMG.Eth.Encoding.ContractConstructor do
  @moduledoc """
  Prepares data for a contract's constructor.
  """

  @doc """
  Extracts a list of 2-element tuples with {type, value}, into a list of types and
  a list of values that can be passed into `ABI.TypeEncoder.encode_raw/1`.

  ## Examples

      iex> OMG.Eth.Encoding.ContractConstructor.extract_params([
      ...>   {:address, "0x1234"},
      ...>   {{:uint, 256}, 1000},
      ...>   {:bool, true}
      ...> ])
      {
        [:address, {:uint, 256}, :bool],
        ["0x1234", 1000, true]
      }
  """
  @spec extract_params(types_values :: [tuple()]) :: {types :: [term()], values :: [term()]}
  def extract_params(types_values) do
    {types, values} =
      Enum.reduce(types_values, {[], []}, fn item, {types, values} ->
        case item do
          {:tuple, elements} ->
            {tuple_types, tuple_values} = extract_params(elements)
            {[{:tuple, tuple_types} | types], [List.to_tuple(tuple_values) | values]}

          {type, arg} ->
            {[type | types], [arg | values]}
        end
      end)

    {Enum.reverse(types), Enum.reverse(values)}
  end
end
