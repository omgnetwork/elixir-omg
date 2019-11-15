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

  @moduletag :common

  describe "encode_constructor_params/1" do
    test "encoding an empty list of params returns an empty string" do
      assert Encoding.encode_constructor_params([]) == ""
    end

    test "returns a valid base16 string when given a list of elementary types" do
      params = [
        {:address, "0x1234"},
        {{:uint, 256}, 1000},
        {{:uint, 256}, 2000},
        {:bool, true}
      ]

      encoded = Encoding.encode_constructor_params(params)

      # This function mainly does encoding via `Elixir.Base` and `ABI.TypeEncoder`,
      # so we'll assert just the expected format, but not the content.
      assert {:ok, _} = Base.decode16(encoded, case: :lower)
    end

    test "returns the correct list of types and values when given a list with one tuple" do
      params = [
        {:tuple, [
          {:address, "0x1234"},
          {{:uint, 256}, 1000},
          {:bool, true},
        ]}
      ]

      encoded = Encoding.encode_constructor_params(params)

      # This function mainly does encoding via `Elixir.Base` and `ABI.TypeEncoder`,
      # so we'll assert just the expected format, but not the content.
      assert {:ok, _} = Base.decode16(encoded, case: :lower)
    end

    test "returns the correct list of types and values when given a list of tuples" do
      params = [
        {:tuple, [
          {:address, "0x1234"},
          {{:uint, 256}, 1000},
          {:bool, true},
        ]},
        {:tuple, [
          {{:uint, 128}, 2000},
          {:bool, false},
        ]}
      ]

      encoded = Encoding.encode_constructor_params(params)

      # This function mainly does encoding via `Elixir.Base` and `ABI.TypeEncoder`,
      # so we'll assert just the expected format, but not the content.
      assert {:ok, _} = Base.decode16(encoded, case: :lower)
    end
  end

  describe "reduce_constructor_params/1" do
    test "returns a tuple of empty lists when given an empty list" do
      encoded = Encoding.reduce_constructor_params([])
      assert encoded == {[], []}
    end

    test "returns the correct list of types and values when given a list of elementary types" do
      params = [
        {:address, "0x1234"},
        {{:uint, 256}, 1000},
        {{:uint, 256}, 2000},
        {:bool, true}
      ]

      encoded = Encoding.reduce_constructor_params(params)

      assert encoded == {
        [:address, {:uint, 256}, {:uint, 256}, :bool],
        ["0x1234", 1000, 2000, true]
      }
    end

    test "returns the correct list of types and values when given a list with one tuple" do
      params = [
        {:tuple, [
          {:address, "0x1234"},
          {{:uint, 256}, 1000},
          {:bool, true},
        ]}
      ]

      encoded = Encoding.reduce_constructor_params(params)

      assert encoded == {
        [{:tuple, [:address, {:uint, 256}, :bool]}],
        [{"0x1234", 1000, true}]
      }
    end

    test "returns the correct list of types and values when given a list of tuples" do
      params = [
        {:tuple, [
          {:address, "0x1234"},
          {{:uint, 256}, 1000},
          {:bool, true},
        ]},
        {:tuple, [
          {{:uint, 128}, 2000},
          {:bool, false},
        ]}
      ]

      encoded = Encoding.reduce_constructor_params(params)

      assert encoded == {
        [{:tuple, [:address, {:uint, 256}, :bool]}, {:tuple, [{:uint, 128}, :bool]}],
        [{"0x1234", 1000, true}, {2000, false}]
      }
    end
  end
end
