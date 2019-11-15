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

defmodule OMG.Eth.EncodingTest do
  use ExUnit.Case, async: true

  alias OMG.Eth.Encoding

  describe "encode_constructor_params/1" do
    test "encodes an empty list of params correctly" do
      encoded = Encoding.encode_constructor_params([])
      assert encoded == {[], []}
    end

    test "encodes a list of types and arguments correctly" do
      params = [
        {:address, "0x1234"},
        {{:uint, 256}, 1000},
        {{:uint, 256}, 2000},
        {:bool, 1}
      ]

      encoded = Encoding.encode_constructor_params(params)

      assert encoded == {
        [:address, {:uint, 256}, {:uint, 256}, :bool],
        ["0x1234", 1000, 2000, 1]
      }
    end

    test "encodes a list with one tuple correctly" do
      params = [
        {:tuple, [
          {:address, "0x1234"},
          {{:uint, 256}, 1000},
          {:bool, 1},
        ]}
      ]

      encoded = Encoding.encode_constructor_params(params)

      assert encoded == {
        [{:tuple, [:address, {:uint, 256}, :bool]}],
        [{"0x1234", 1000, 1}]
      }
    end

    test "encodes a list of tuple correctly" do
      params = [
        {:tuple, [
          {:address, "0x1234"},
          {{:uint, 256}, 1000},
          {:bool, 1},
        ]},
        {:tuple, [
          {{:uint, 128}, 2000},
          {:bool, 0},
        ]}
      ]

      encoded = Encoding.encode_constructor_params(params)

      assert encoded == {
        [{:tuple, [:address, {:uint, 256}, :bool]}, {:tuple, [{:uint, 128}, :bool]}],
        [{"0x1234", 1000, 1}, {2000, 0}]
      }
    end
  end
end
