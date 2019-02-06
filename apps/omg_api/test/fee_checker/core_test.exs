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

  import OMG.API.FeeChecker.Core

  @eth <<0::160>>
  @fee_config_file ~s(
    [
      { "token": "0x0000000000000000000000000000000000000000", "flat_fee": 2 },
      { "token": "0xd26114cd6ee289accf82350c8d8487fedb8a0c07", "flat_fee": 0 },
      { "token": "0xa74476443119a942de498590fe1f2454d7d4ac0d", "flat_fee": 4 }
    ]
  )

  describe "Parser output:" do
    test "parse valid data is successful" do
      assert {[], fee_map} = parse_file_content(@fee_config_file)

      assert Enum.count(fee_map) == 3
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
