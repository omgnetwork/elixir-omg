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

defmodule OMG.Eth.Encoding.ContractConstructorTest do
  use ExUnit.Case, async: true

  alias OMG.Eth.Encoding.ContractConstructor

  @moduletag :common

  doctest ContractConstructor

  describe "extract_params/1" do
    test "returns a tuple with empty lists when given an empty list" do
      encoded = ContractConstructor.extract_params([])
      assert encoded == {[], []}
    end

    test "returns the correct list of types and values when given a list of elementary types" do
      params = [
        {:address, "0x1234"},
        {{:uint, 256}, 1000},
        {{:uint, 256}, 2000},
        {:bool, true}
      ]

      encoded = ContractConstructor.extract_params(params)

      assert encoded == {
               [:address, {:uint, 256}, {:uint, 256}, :bool],
               ["0x1234", 1000, 2000, true]
             }
    end

    test "returns the correct list of types and values when given a list with one tuple" do
      params = [
        {:tuple,
         [
           {:address, "0x1234"},
           {{:uint, 256}, 1000},
           {:bool, true}
         ]}
      ]

      encoded = ContractConstructor.extract_params(params)

      assert encoded == {
               [{:tuple, [:address, {:uint, 256}, :bool]}],
               [{"0x1234", 1000, true}]
             }
    end

    test "returns the correct list of types and values when given a list of tuples" do
      params = [
        {:tuple,
         [
           {:address, "0x1234"},
           {{:uint, 256}, 1000},
           {:bool, true}
         ]},
        {:tuple,
         [
           {{:uint, 128}, 2000},
           {:bool, false}
         ]}
      ]

      encoded = ContractConstructor.extract_params(params)

      assert encoded == {
               [{:tuple, [:address, {:uint, 256}, :bool]}, {:tuple, [{:uint, 128}, :bool]}],
               [{"0x1234", 1000, true}, {2000, false}]
             }
    end
  end
end
