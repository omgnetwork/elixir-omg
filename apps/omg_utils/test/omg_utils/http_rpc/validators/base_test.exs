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
  alias OMG.Utils.HttpRPC.Encoding

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
    "valid_address" => "0x" <> String.duplicate("00", 20),
    "non_hex_address" => "0x" <> String.duplicate("ZZ", 20),
    "too_long_address" => "0x" <> String.duplicate("00", 21),
    "too_short_address" => "0x" <> String.duplicate("00", 19),
    "valid_signature" => "0x" <> String.duplicate("00", 65),
    "non_hex_signature" => "0x" <> String.duplicate("ZZ", 65),
    "too_long_signature" => "0x" <> String.duplicate("00", 66),
    "too_short_signature" => "0x" <> String.duplicate("00", 64),
    "valid_hash" => "0x" <> String.duplicate("00", 32),
    "non_hex_hash" => "0x" <> String.duplicate("ZZ", 32),
    "too_long_hash" => "0x" <> String.duplicate("00", 33),
    "too_short_hash" => "0x" <> String.duplicate("00", 31),
    "len_1" => "1",
    "len_2" => <<1, 2, 3, 4, 5>>,
    "max_len_1" => [1, 2, 3, 4, 5]
  }

  describe "Basic validation:" do
    test "integer: positive cases" do
      assert {:ok, -1_234_567_890} == expect(@params, "int_1", :integer)
      assert {:ok, 0} == expect(@params, "int_2", :integer)
      assert {:ok, 1_234_567_890} == expect(@params, "int_3", [:integer])
    end

    test "integer: negative cases" do
      assert {:error, {:validation_error, "nint_1", :integer}} == expect(@params, "nint_1", :integer)
      assert {:error, {:validation_error, "nil", :integer}} == expect(@params, "nil", :integer)
    end

    test "optional: positive cases" do
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

    test "optional: negative cases" do
      assert {:error, {:validation_error, "nil", :integer}} == expect(@params, "nil", [:optional, :integer])
    end

    test "hex: positive cases" do
      assert {:ok, @bin_value} == expect(@params, "hex_1", :hex)
      assert {:ok, @bin_value} == expect(@params, "hex_2", :hex)
      assert {:ok, @bin_value} == expect(@params, "hex_3", :hex)
    end

    test "hex: negative cases" do
      assert {:error, {:validation_error, "nhex_1", :hex}} == expect(@params, "nhex_1", :hex)
    end

    test "length: positive cases" do
      assert {:ok, "1"} == expect(@params, "len_1", length: 1)
      assert {:ok, <<1, 2, 3, 4, 5>>} == expect(@params, "len_2", length: 5)
      assert {:ok, [1, 2, 3, 4, 5]} == expect(@params, "max_len_1", max_length: 10)
      assert {:ok, [1, 2, 3, 4, 5]} == expect(@params, "max_len_1", max_length: 5)
    end

    test "length: negative cases" do
      assert {:error, {:validation_error, "len_1", {:length, 5}}} == expect(@params, "len_1", length: 5)
      assert {:error, {:validation_error, "len_2", {:length, 1}}} == expect(@params, "len_2", length: 1)
      assert {:error, {:validation_error, "max_len_1", {:max_length, 3}}} == expect(@params, "max_len_1", max_length: 3)
    end

    test "max_length: positive cases" do
      assert {:ok, [1, 2, 3, 4, 5]} == expect(@params, "max_len_1", max_length: 10)
      assert {:ok, [1, 2, 3, 4, 5]} == expect(@params, "max_len_1", max_length: 5)
    end

    test "max_length: negative cases" do
      assert {:error, {:validation_error, "max_len_1", {:max_length, 3}}} == expect(@params, "max_len_1", max_length: 3)
    end

    test "list: positive cases" do
      list = [1, "a", :b]
      assert {:ok, list} == expect(%{"list" => list}, "list", :list)
    end

    test "list: negative cases" do
      assert {:error, {:validation_error, "list", :list}} == expect(%{"list" => "[42]"}, "list", :list)
    end

    test "map: positive cases" do
      map = %{"a" => 0, "b" => 1}
      assert {:ok, map} == expect(%{"map" => map}, "map", :map)
    end

    test "map: negative cases" do
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

      {:ok, address_value} = @params |> Map.get("valid_address") |> Encoding.from_hex()

      assert {:ok, %{currency: address_value, amount: 100}} =
               expect(
                 %{"fee" => %{"currency" => @params["valid_address"], "amount" => 100}},
                 "fee",
                 map: parser
               )

      assert {:error, {:validation_error, "fee.currency", :hex}} =
               expect(
                 %{"fee" => %{"currency" => @params["non_hex_address"], "amount" => 100}},
                 "fee",
                 map: parser
               )
    end

    test "unwrapping results list" do
      list = Enum.to_list(0..9)

      ok_list = Enum.map(list, &{:ok, &1})
      assert list == all_success_or_error(ok_list)

      error = {:error, "bad news"}
      list_with_err = Enum.shuffle([error | ok_list])
      assert error == all_success_or_error(list_with_err)
    end
  end

  describe "Preprocessors:" do
    test "greater: positive cases" do
      assert {:ok, 0} == expect(@params, "int_2", greater: -1)

      assert {:ok, 1_234_567_890} == expect(@params, "int_3", greater: 1_000_000_000)
    end

    test "greater: negative cases" do
      assert {:error, {:validation_error, "int_2", {:greater, 0}}} == expect(@params, "int_2", greater: 0)

      assert {:error, {:validation_error, "nint_1", :integer}} == expect(@params, "nint_1", greater: 0)
    end

    test "address should validate both hex value and length" do
      {:ok, address_value} = @params |> Map.get("valid_address") |> Encoding.from_hex()
      assert {:ok, address_value} == expect(@params, "valid_address", :address)

      assert {:error, {:validation_error, "non_hex_address", :hex}} == expect(@params, "non_hex_address", :address)

      assert {:error, {:validation_error, "too_short_address", {:length, 20}}} ==
               expect(@params, "too_short_address", :address)

      assert {:error, {:validation_error, "too_long_address", {:length, 20}}} ==
               expect(@params, "too_long_address", :address)
    end

    test "signature should validate both hex value and length" do
      {:ok, signature_value} = @params |> Map.get("valid_signature") |> Encoding.from_hex()
      assert {:ok, signature_value} == expect(@params, "valid_signature", :signature)

      assert {:error, {:validation_error, "non_hex_signature", :hex}} ==
               expect(@params, "non_hex_signature", :signature)

      assert {:error, {:validation_error, "too_short_signature", {:length, 65}}} ==
               expect(@params, "too_short_signature", :signature)

      assert {:error, {:validation_error, "too_long_signature", {:length, 65}}} ==
               expect(@params, "too_long_signature", :signature)
    end

    test "hash should validate both hex value and length" do
      {:ok, hash_value} = @params |> Map.get("valid_hash") |> Encoding.from_hex()
      assert {:ok, hash_value} == expect(@params, "valid_hash", :hash)

      assert {:error, {:validation_error, "non_hex_hash", :hex}} ==
               expect(@params, "non_hex_hash", :hash)

      assert {:error, {:validation_error, "too_short_hash", {:length, 32}}} ==
               expect(@params, "too_short_hash", :hash)

      assert {:error, {:validation_error, "too_long_hash", {:length, 32}}} ==
               expect(@params, "too_long_hash", :hash)
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
