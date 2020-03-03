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
defmodule OMG.ChildChain.Fees.JSONSingleSpecParserTest do
  @moduledoc false
  use ExUnitFixtures
  use ExUnit.Case, async: true
  alias OMG.ChildChain.Fees.JSONSingleSpecParser
  alias OMG.Eth

  @eth Eth.zero_address()

  @valid_spec %{
    "token" => "0x" <> Base.encode16(@eth),
    "amount" => 1,
    "subunit_to_unit" => 1_000_000_000_000_000_000,
    "pegged_amount" => 1,
    "pegged_currency" => "USD",
    "pegged_subunit_to_unit" => 100,
    "updated_at" => "2019-01-01T10:10:00+00:00"
  }

  describe "parse/1" do
    test "correctly parse and return a valid spec" do
      assert {:ok,
              %{
                token: @eth,
                amount: 1,
                subunit_to_unit: 1_000_000_000_000_000_000,
                pegged_amount: 1,
                pegged_currency: "USD",
                pegged_subunit_to_unit: 100,
                updated_at: "2019-01-01T10:10:00+00:00" |> DateTime.from_iso8601() |> elem(1)
              }} == JSONSingleSpecParser.parse(@valid_spec)
    end

    test "accepts a nil value for all pegged fields" do
      spec =
        @valid_spec
        |> Map.put("pegged_amount", nil)
        |> Map.put("pegged_currency", nil)
        |> Map.put("pegged_subunit_to_unit", nil)

      assert {:ok,
              %{
                token: @eth,
                amount: 1,
                subunit_to_unit: 1_000_000_000_000_000_000,
                pegged_amount: nil,
                pegged_currency: nil,
                pegged_subunit_to_unit: nil,
                updated_at: "2019-01-01T10:10:00+00:00" |> DateTime.from_iso8601() |> elem(1)
              }} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_pegged_fields` error when given a nil pegged_amount alone" do
      spec = Map.put(@valid_spec, "pegged_amount", nil)

      assert {:error, :invalid_pegged_fields} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_pegged_fields` error when given a nil pegged_currency alone" do
      spec = Map.put(@valid_spec, "pegged_currency", nil)

      assert {:error, :invalid_pegged_fields} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_pegged_fields` error when given a nil pegged_subunit_to_unit alone" do
      spec = Map.put(@valid_spec, "pegged_subunit_to_unit", nil)

      assert {:error, :invalid_pegged_fields} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_fee_spec` error when given an invalid map" do
      spec = %{"invalid_key" => "something"}

      assert {:error, :invalid_fee_spec} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_fee` error when given a negative fee" do
      spec = Map.put(@valid_spec, "amount", -1)

      assert {:error, :invalid_fee} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_fee` error when given a zero fee" do
      spec = Map.put(@valid_spec, "amount", 0)

      assert {:error, :invalid_fee} == JSONSingleSpecParser.parse(spec)
    end

    test "returns a `bad_address_encoding` error when given an invalid token" do
      spec = Map.put(@valid_spec, "token", "Not a token")

      assert {:error, :bad_address_encoding} == JSONSingleSpecParser.parse(spec)
    end

    test "returns a `bad_address_encoding` error when given a token with a length != 20 bytes" do
      spec = Map.put(@valid_spec, "token", "0x0123456789abCdeF")

      assert {:error, :bad_address_encoding} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_pegged_amount` error when given a negative pegged_amount" do
      spec = Map.put(@valid_spec, "pegged_amount", -1)

      assert {:error, :invalid_pegged_amount} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_pegged_amount` error when given zero pegged_amount" do
      spec = Map.put(@valid_spec, "pegged_amount", 0)

      assert {:error, :invalid_pegged_amount} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_pegged_currency` error when given a non binary pegged_currency" do
      spec = Map.put(@valid_spec, "pegged_currency", 12)

      assert {:error, :invalid_pegged_currency} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_pegged_subunit_to_unit` error when given a negative pegged_subunit_to_unit" do
      spec = Map.put(@valid_spec, "pegged_subunit_to_unit", -1)

      assert {:error, :invalid_pegged_subunit_to_unit} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_pegged_subunit_to_unit` error when given a zero pegged_subunit_to_unit" do
      spec = Map.put(@valid_spec, "pegged_subunit_to_unit", 0)

      assert {:error, :invalid_pegged_subunit_to_unit} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_subunit_to_unit` error when given a negative subunit_to_unit" do
      spec = Map.put(@valid_spec, "subunit_to_unit", -1)

      assert {:error, :invalid_subunit_to_unit} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_subunit_to_unit` error when given a zero subunit_to_unit" do
      spec = Map.put(@valid_spec, "subunit_to_unit", 0)

      assert {:error, :invalid_subunit_to_unit} == JSONSingleSpecParser.parse(spec)
    end

    test "returns an `invalid_timestamp` error when given an invalid binary datetime" do
      spec = Map.put(@valid_spec, "updated_at", "invalid_date")

      assert {:error, :invalid_timestamp} == JSONSingleSpecParser.parse(spec)
    end
  end
end
