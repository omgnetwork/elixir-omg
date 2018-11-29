# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.API.FeeChecker.CoreTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.API.TestHelper, as: Test

  import OMG.API.FeeChecker.Core

  @eth <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
  @omg <<210, 97, 20, 205, 110, 226, 137, 172, 207, 130, 53, 12, 141, 132, 135, 254, 219, 138, 12, 7>>
  @fee_config_file ~s(
    [
      { "token": "0x0000000000000000000000000000000000000000", "flat_fee": 2 },
      { "token": "0xd26114cd6ee289accf82350c8d8487fedb8a0c07", "flat_fee": 0 },
      { "token": "0xa74476443119a942de498590fe1f2454d7d4ac0d", "flat_fee": 4 },
      { "token": "0x4156d3342d5c385a87d264f90653733592000581", "flat_fee": 3 },
      { "token": "0x81c9151de0c8bafcd325a57e3db5a5df1cebf79c", "flat_fee": 5 }
    ]
  )

  describe "Transaction fees:" do
    @tag fixtures: [:alice, :bob]
    test "returns tx currency and flat fee associated with this currency", %{alice: alice, bob: bob} do
      tx = Test.create_recovered([{1, 0, 0, alice}], [{bob, @eth, 10}])

      assert {[], fee_map} = parse_file_content(@fee_config_file)
      assert {:ok, %{@eth => 2}} = transaction_fees(tx, fee_map)
    end

    @tag fixtures: [:alice, :bob]
    test "returns zero fee - when currency is configured with zero fee", %{alice: alice, bob: bob} do
      tx = Test.create_recovered([{1, 0, 0, alice}], [{bob, @omg, 10}])

      assert {[], fee_map} = parse_file_content(@fee_config_file)
      assert {:ok, %{@omg => 0}} = transaction_fees(tx, fee_map)
    end

    @tag fixtures: [:alice, :bob]
    test "returns :token_not_allowed - when currency is not contained in config file", %{alice: alice, bob: bob} do
      invalid_currency = <<1::size(160)>>
      tx = Test.create_recovered([{1, 0, 0, alice}], [{bob, invalid_currency, 10}])

      assert {[], fee_map} = parse_file_content(@fee_config_file)
      assert {:error, :token_not_allowed} = transaction_fees(tx, fee_map)
    end
  end

  describe "Parser output:" do
    test "parse valid data is successful" do
      assert {[], fee_map} = parse_file_content(@fee_config_file)

      assert Enum.count(fee_map) == 5
      assert fee_map[@eth] == 2
    end

    test "empty fee spec list is parsed correctly" do
      assert {[], %{}} = parse_file_content("[]")
    end

    test "parse invalid data return errors" do
      json = ~s([
        {
          "invalid_key": null,
          "error_reason": "Providing unexpeced map results with :invalid_fee_spec error"
        },
        {
          "token": "0x0000000000000000000000000000000000000000",
          "flat_fee": -1,
          "error_reason": "Negative fee results with :invalid_fee error"
        },
        {
          "token": "this is not HEX",
          "flat_fee": 0,
          "error_reason": "Wrongly formatted token results with :invalid_token error"
        },
        {
          "token": "0x0123456789abCdeF",
          "flat_fee": 1,
          "error_reason": "Tokens length other than 20 bytes results with :invalid_token error"
        }
      ])

      expected_errors = [
        {{:error, :invalid_fee_spec}, 1},
        {{:error, :invalid_fee}, 2},
        {{:error, :bad_address_encoding}, 3},
        {{:error, :bad_address_encoding}, 4}
      ]

      assert {^expected_errors, _} = parse_file_content(json)
    end

    test "json with duplicate tokens returns error" do
      json = ~s([
        {"token": "0x0000000000000000000000000000000000000000", "flat_fee": 1},
        {"token": "0x0000000000000000000000000000000000000000", "flat_fee": 2}
      ])

      expected_errors = [{{:error, :duplicate_token}, 2}]

      assert {^expected_errors, _} = parse_file_content(json)
    end
  end
end
