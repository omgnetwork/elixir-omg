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

defmodule OMG.ChildChain.FeeParserTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true

  import OMG.ChildChain.FeeParser

  alias OMG.Eth

  @fee_config_file ~s(
    [
      {
        "token": "0x0000000000000000000000000000000000000000",
        "amount": 2,
        "subunit_to_unit": 1000000000000000000,
        "pegged_amount": 1,
        "pegged_currency": "USD",
        "pegged_subunit_to_unit": 100,
        "updated_at": "2019-01-01T10:10:00+00:00"
      },
      {
        "token": "0xd26114cd6ee289accf82350c8d8487fedb8a0c07",
        "amount": 0,
        "subunit_to_unit": 1000000000000000000,
        "pegged_amount": 1,
        "pegged_currency": "USD",
        "pegged_subunit_to_unit": 100,
        "updated_at": "2019-01-01T10:10:00+00:00"
      },
      {
        "token": "0xa74476443119a942de498590fe1f2454d7d4ac0d",
        "amount": 4,
        "subunit_to_unit": 1000000000000000000,
        "pegged_amount": 1,
        "pegged_currency": "USD",
        "pegged_subunit_to_unit": 100,
        "updated_at": "2019-01-01T10:10:00+00:00"
      }
    ]
  )

  @eth Eth.zero_address()

  describe "Parser output:" do
    test "parse valid data is successful" do
      assert {:ok, fee_map} = parse_file_content(@fee_config_file)

      assert Enum.count(fee_map) == 3
      assert fee_map[@eth][:amount] == 2
    end

    test "empty fee spec list is parsed correctly" do
      assert {:ok, %{}} = parse_file_content("[]")
    end

    @tag :capture_log
    test "parse invalid data return errors" do
      json = ~s([
        {
          "invalid_key": null,
          "error_reason": "Providing unexpected map results with :invalid_fee_spec error"
        },
        {
          "token": "0x0000000000000000000000000000000000000000",
          "amount": -1,
          "subunit_to_unit": 1000000000000000000,
          "pegged_amount": 1,
          "pegged_currency": "USD",
          "pegged_subunit_to_unit": 100,
          "updated_at": "2019-01-01T10:10:00+00:00",
          "error_reason": "Negative fee results with :invalid_fee error"
        },
        {
          "token": "this is not HEX",
          "amount": 0,
          "subunit_to_unit": 1000000000000000000,
          "pegged_amount": 1,
          "pegged_currency": "USD",
          "pegged_subunit_to_unit": 100,
          "updated_at": "2019-01-01T10:10:00+00:00",
          "error_reason": "Wrongly formatted token results with :invalid_token error"
        },
        {
          "token": "0x0123456789abCdeF",
          "amount": 1,
          "subunit_to_unit": 1000000000000000000,
          "pegged_amount": 1,
          "pegged_currency": "USD",
          "pegged_subunit_to_unit": 100,
          "updated_at": "2019-01-01T10:10:00+00:00",
          "error_reason": "Tokens length other than 20 bytes results with :invalid_token error"
        },
        {
          "token": "0x0000000000000000000000000000000000000000",
          "amount": 1,
          "subunit_to_unit": 1000000000000000000,
          "pegged_amount": -1,
          "pegged_currency": "USD",
          "pegged_subunit_to_unit": 100,
          "updated_at": "2019-01-01T10:10:00+00:00",
          "error_reason": "Negative pegged_amount results with :invalid_pegged_amount error"
        },
        {
          "token": "0x0000000000000000000000000000000000000000",
          "amount": 1,
          "subunit_to_unit": 1000000000000000000,
          "pegged_amount": 0,
          "pegged_currency": "USD",
          "pegged_subunit_to_unit": 100,
          "updated_at": "2019-01-01T10:10:00+00:00",
          "error_reason": "0 pegged_amount results with :invalid_pegged_amount error"
        },
        {
          "token": "0x0000000000000000000000000000000000000000",
          "amount": 1,
          "subunit_to_unit": 1000000000000000000,
          "pegged_amount": 1,
          "pegged_currency": 12,
          "pegged_subunit_to_unit": 100,
          "updated_at": "2019-01-01T10:10:00+00:00",
          "error_reason": "Non binary pegged_currency results with :invalid_pegged_currency error"
        },
        {
          "token": "0x0000000000000000000000000000000000000000",
          "amount": 1,
          "subunit_to_unit": 1000000000000000000,
          "pegged_amount": 1,
          "pegged_currency": "USD",
          "pegged_subunit_to_unit": -1,
          "updated_at": "2019-01-01T10:10:00+00:00",
          "error_reason": "Negative pegged_subunit_to_unit results with :invalid_pegged_subunit_to_unit error"
        },
        {
          "token": "0x0000000000000000000000000000000000000000",
          "amount": 1,
          "subunit_to_unit": 1000000000000000000,
          "pegged_amount": 1,
          "pegged_currency": "USD",
          "pegged_subunit_to_unit": 0,
          "updated_at": "2019-01-01T10:10:00+00:00",
          "error_reason": "0 pegged_subunit_to_unit results with :invalid_pegged_subunit_to_unit error"
        },
        {
          "token": "0x0000000000000000000000000000000000000000",
          "amount": 1,
          "subunit_to_unit": 1000000000000000000,
          "pegged_amount": 1,
          "pegged_currency": "USD",
          "pegged_subunit_to_unit": 100,
          "updated_at": "invalid_date",
          "error_reason": "Invalid updated_at results with :invalid_timestamp error"
        },
        {
          "token": "0x0000000000000000000000000000000000000000",
          "amount": 1,
          "subunit_to_unit": -1,
          "pegged_amount": 1,
          "pegged_currency": "USD",
          "pegged_subunit_to_unit": 100,
          "updated_at": "2019-01-01T10:10:00+00:00",
          "error_reason": "Negative pegged_amount results with :invalid_subunit_to_unit error"
        },
        {
          "token": "0x0000000000000000000000000000000000000000",
          "amount": 1,
          "subunit_to_unit": 0,
          "pegged_amount": 1,
          "pegged_currency": "USD",
          "pegged_subunit_to_unit": 100,
          "updated_at": "2019-01-01T10:10:00+00:00",
          "error_reason": "0 pegged_amount results with :invalid_subunit_to_unit error"
        }
      ])

      assert {:error,
              [
                {{:error, :invalid_fee_spec}, 1},
                {{:error, :invalid_fee}, 2},
                {{:error, :bad_address_encoding}, 3},
                {{:error, :bad_address_encoding}, 4},
                {{:error, :invalid_pegged_amount}, 5},
                {{:error, :invalid_pegged_amount}, 6},
                {{:error, :invalid_pegged_currency}, 7},
                {{:error, :invalid_pegged_subunit_to_unit}, 8},
                {{:error, :invalid_pegged_subunit_to_unit}, 9},
                {{:error, :invalid_timestamp}, 10},
                {{:error, :invalid_subunit_to_unit}, 11},
                {{:error, :invalid_subunit_to_unit}, 12}
              ]} = parse_file_content(json)
    end

    @tag :capture_log
    test "json with duplicate tokens returns error" do
      json = ~s([
        {
          "token": "0x0000000000000000000000000000000000000000",
          "amount": 1,
          "subunit_to_unit": 1000000000000000000,
          "pegged_amount": 1,
          "pegged_currency": "USD",
          "pegged_subunit_to_unit": 100,
          "updated_at": "2019-01-01T10:10:00+00:00"
        },
        {
          "token": "0x0000000000000000000000000000000000000000",
          "amount": 2,
          "subunit_to_unit": 1000000000000000000,
          "pegged_amount": 1,
          "pegged_currency": "USD",
          "pegged_subunit_to_unit": 100,
          "updated_at": "2019-01-01T10:10:00+00:00"
        }
      ])

      assert {:error, [{{:error, :duplicate_token}, 2}]} = parse_file_content(json)
    end
  end
end
