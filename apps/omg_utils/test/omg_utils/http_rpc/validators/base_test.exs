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

defmodule OMG.Utils.HttpRPC.Validator.BaseTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  import OMG.Utils.HttpRPC.Validator.Base

  @bin_value <<179, 37, 96, 38, 134, 62, 182, 174, 91, 6, 250, 57, 106, 176, 144, 105, 120, 78, 168, 234>>
  @params %{
    "int_1" => -1_234_567_890,
    "int_2" => 0,
    "int_3" => 1_234_567_890,
    "nint_1" => "1234567890",
    "nil" => nil,
    "opt_1" => true,
    "hex_1" => "0xb3256026863eb6ae5b06fa396ab09069784ea8ea",
    "hex_2" => "0xB3256026863EB6aE5B06fA396AB09069784ea8eA",
    "hex_3" => "0xB3256026863EB6AE5B06FA396AB09069784EA8EA",
    "nhex_1" => "b3256026863eb6ae5b06fa396ab09069784ea8ea",
    "len_1" => "1",
    "len_2" => <<1, 2, 3, 4, 5>>
  }

  describe "Basic validation:" do
    test "integer, positive" do
      assert {:ok, -1_234_567_890} == expect(@params, "int_1", :integer)

      assert {:ok, 0} == expect(@params, "int_2", :integer)

      assert {:ok, 1_234_567_890} == expect(@params, "int_3", [:integer])
    end

    test "integer, negative" do
      assert {:error, {:validation_error, "nint_1", :integer}} == expect(@params, "nint_1", :integer)

      assert {:error, {:validation_error, "nil", :integer}} == expect(@params, "nil", :integer)
    end

    test "optional, positive" do
      assert {:ok, 0} == expect(@params, "int_2", :optional)
      assert {:ok, true} == expect(@params, "opt_1", :optional)
      assert {:ok, nil} == expect(@params, "no_such_key", [:optional])

      assert {:ok, nil} == expect(@params, "nil", [:integer, :optional])
      assert {:ok, 1_234_567_890} == expect(@params, "int_3", [:integer, :optional])
    end

    test "optional, list" do
      list = [1, 2, 3]
      assert {:ok, list} == expect(%{"list" => list}, "list", [:list, :optional])
      assert {:ok, nil} == expect(%{}, "list", [:list, :optional])
      assert {:ok, nil} == expect(%{}, "list", list: &(&1 * 2), optional: true)
      assert {:ok, [2, 4, 6]} == expect(%{"list" => list}, "list", list: &(&1 * 2), optional: true)
      assert {:error, {:validation_error, "list", :list}} == expect(%{}, "list", list: &(&1 * 2), optional: false)
    end

    test "optional, negative" do
      assert {:error, {:validation_error, "nil", :integer}} == expect(@params, "nil", [:optional, :integer])
    end

    test "hex, positive" do
      assert {:ok, @bin_value} == expect(@params, "hex_1", :hex)
      assert {:ok, @bin_value} == expect(@params, "hex_2", :hex)
      assert {:ok, @bin_value} == expect(@params, "hex_3", :hex)
    end

    test "hex, negative" do
      assert {:error, {:validation_error, "nhex_1", :hex}} == expect(@params, "nhex_1", :hex)
    end

    test "length, positive" do
      assert {:ok, "1"} == expect(@params, "len_1", length: 1)
      assert {:ok, <<1, 2, 3, 4, 5>>} == expect(@params, "len_2", length: 5)
    end

    test "length, negative" do
      assert {:error, {:validation_error, "len_1", {:length, 5}}} == expect(@params, "len_1", length: 5)
      assert {:error, {:validation_error, "len_2", {:length, 1}}} == expect(@params, "len_2", length: 1)
    end

    test "list, positive" do
      list = [1, "a", :b]
      assert {:ok, list} == expect(%{"list" => list}, "list", :list)
    end

    test "list, negative" do
      assert {:error, {:validation_error, "list", :list}} == expect(%{"list" => "[42]"}, "list", :list)
    end

    test "map, positive" do
      map = %{"a" => 0, "b" => 1}
      assert {:ok, map} == expect(%{"map" => map}, "map", :map)
    end

    test "map, negative" do
      assert {:error, {:validation_error, "map", :map}} == expect(%{"map" => [42]}, "map", :map)
    end

    test "map, missing" do
      assert {:error, {:validation_error, "map", :map}} == expect(%{}, "map", :map)
    end
  end

  describe "list and map preprocessing:" do
    test "mapping list elements" do
      assert {:ok, [2, 4, 6]} == expect(%{"list" => [1, 2, 3]}, "list", list: &(&1 * 2))
    end

    test "validating list elements" do
      is_even = fn
        elt when rem(elt, 2) == 0 -> {:ok, elt}
        _ -> {:error, :odd_number}
      end

      assert {:ok, [2, 4, 6]} ==
               expect(
                 %{"all_even" => [2, 4, 6]},
                 "all_even",
                 list: is_even
               )

      assert {:error, {:validation_error, "all_even", :odd_number}} ==
               expect(
                 %{"all_even" => [2, 3, 6]},
                 "all_even",
                 list: is_even
               )
    end

    test "parsing map" do
      parser = fn map ->
        with {:ok, currency} <- expect(map, "currency", :address),
             {:ok, amount} <- expect(map, "amount", :non_neg_integer),
             do: {:ok, %{currency: currency, amount: amount}}
      end

      assert {:ok, %{currency: @bin_value, amount: 100}} =
               expect(
                 %{"fee" => %{"currency" => @params["hex_2"], "amount" => 100}},
                 "fee",
                 map: parser
               )

      assert {:error, {:validation_error, "fee.currency", :hex}} =
               expect(
                 %{"fee" => %{"currency" => "not-an-address", "amount" => 100}},
                 "fee",
                 map: parser
               )
    end

    test "unwrapping results list" do
      list = 0..9 |> Enum.to_list()

      ok_list = list |> Enum.map(&{:ok, &1})
      assert list == all_success_or_error(ok_list)

      error = {:error, "bad news"}
      list_with_err = [error | ok_list] |> Enum.shuffle()
      assert error == all_success_or_error(list_with_err)
    end
  end

  describe "Preprocessors:" do
    test "greater, positive" do
      assert {:ok, 0} == expect(@params, "int_2", greater: -1)

      assert {:ok, 1_234_567_890} == expect(@params, "int_3", greater: 1_000_000_000)
    end

    test "greater, negative" do
      assert {:error, {:validation_error, "int_2", {:greater, 0}}} == expect(@params, "int_2", greater: 0)

      assert {:error, {:validation_error, "nint_1", :integer}} == expect(@params, "nint_1", greater: 0)
    end

    test "address should validate both hex value and its length" do
      assert {:ok, @bin_value} == expect(@params, "hex_1", :address)

      assert {:error, {:validation_error, "nhex_1", :hex}} == expect(@params, "nhex_1", :address)

      assert {:error, {:validation_error, "short", {:length, 20}}} ==
               expect(%{"short" => "0xdeadbeef"}, "short", :address)
    end
  end

  test "positive and non negative integers" do
    args = %{
      "neg" => -1,
      "zero" => 0,
      "pos" => 1,
      "NaN" => true
    }

    assert {:ok, 0} == expect(args, "zero", :non_neg_integer)
    assert {:error, {:validation_error, "neg", {:greater, -1}}} == expect(args, "neg", :non_neg_integer)

    assert {:ok, 1} == expect(args, "pos", :pos_integer)

    assert {:error, {:validation_error, "zero", {:greater, 0}}} == expect(args, "zero", :pos_integer)

    assert {:error, {:validation_error, "NaN", :integer}} == expect(args, "NaN", :pos_integer)
  end
end
