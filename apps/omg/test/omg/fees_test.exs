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

defmodule OMG.FeesTest do
  @moduledoc false

  use ExUnitFixtures
  use OMG.Fixtures
  use ExUnit.Case, async: true

  import OMG.Fees
  import OMG.TestHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @not_eth <<1::size(160)>>

  @fees %{
    @eth => 1,
    @not_eth => 3
  }

  @fee_config_file ~s(
    [
      { "token": "0x0000000000000000000000000000000000000000", "flat_fee": 2 },
      { "token": "0xd26114cd6ee289accf82350c8d8487fedb8a0c07", "flat_fee": 0 },
      { "token": "0xa74476443119a942de498590fe1f2454d7d4ac0d", "flat_fee": 4 }
    ]
  )

  describe "Parser output:" do
    test "parse valid data is successful" do
      assert {:ok, fee_map} = parse_file_content(@fee_config_file)

      assert Enum.count(fee_map) == 3
      assert fee_map[@eth] == 2
    end

    test "empty fee spec list is parsed correctly" do
      assert {:ok, %{}} = parse_file_content("[]")
    end

    @tag :capture_log
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

      assert {:error,
              [
                {{:error, :invalid_fee_spec}, 1},
                {{:error, :invalid_fee}, 2},
                {{:error, :bad_address_encoding}, 3},
                {{:error, :bad_address_encoding}, 4}
              ]} = parse_file_content(json)
    end

    @tag :capture_log
    test "json with duplicate tokens returns error" do
      json = ~s([
        {"token": "0x0000000000000000000000000000000000000000", "flat_fee": 1},
        {"token": "0x0000000000000000000000000000000000000000", "flat_fee": 2}
      ])

      assert {:error, [{{:error, :duplicate_token}, 2}]} = parse_file_content(json)
    end
  end

  @tag fixtures: [:alice, :bob]
  test "Transactions covers the fee only in one currency accepted by the operator", %{alice: alice, bob: bob} do
    fees =
      create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 3}])
      |> for_tx(@fees)

    assert covered?(%{@eth => 10}, %{@eth => 9}, fees)

    fees =
      create_recovered([{1, 0, 0, alice}], @not_eth, [{bob, 4}, {alice, 3}])
      |> for_tx(@fees)

    assert covered?(%{@not_eth => 10}, %{@not_eth => 7}, fees)

    fees =
      create_recovered(
        [{1, 0, 0, alice}, {2, 0, 0, alice}],
        [{bob, @eth, 4}, {alice, @eth, 1}, {bob, @not_eth, 5}, {alice, @not_eth, 5}]
      )
      |> for_tx(@fees)

    assert covered?(
             %{@eth => 5, @not_eth => 13},
             %{@eth => 5, @not_eth => 10},
             fees
           )
  end

  @tag fixtures: [:alice, :bob]
  test "Transaction which does not transfer any fee currency is object to fees", %{alice: alice, bob: bob} do
    other_token = <<2::160>>

    fees =
      create_recovered([{1, 0, 0, alice}], other_token, [{bob, 5}, {alice, 3}])
      |> for_tx(@fees)

    assert false == covered?(%{other_token => 10}, %{other_token => 7}, fees)
  end

  @tag fixtures: [:alice, :bob]
  test "Transaction can dedicate one input for a fee entirely, reducing to tx's outputs currencies is incorrect",
       %{alice: alice, bob: bob} do
    other_token = <<2::160>>

    fees =
      create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, other_token, 5}, {alice, other_token, 5}])
      |> for_tx(@fees)

    assert covered?(%{@not_eth => 5, other_token => 10}, %{other_token => 10}, fees)
  end

  describe "Merge transactions are free of cost" do
    @tag fixtures: [:alice]
    test "merging utxo erases the fee", %{alice: alice} do
      fees =
        create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], @not_eth, [{alice, 10}])
        |> for_tx(@fees)

      assert covered?(%{@not_eth => 10}, %{@not_eth => 10}, fees)
    end

    @tag fixtures: [:alice]
    test "merge is single currency transaction", %{alice: alice} do
      fees =
        create_recovered(
          [{1, 0, 0, alice}, {1, 0, 1, alice}, {2, 0, 0, alice}, {2, 1, 0, alice}],
          [{alice, @eth, 10}, {alice, @not_eth, 10}]
        )
        |> for_tx(@fees)

      assert not covered?(
               %{@eth => 10, @not_eth => 10},
               %{@eth => 10, @not_eth => 10},
               fees
             )
    end

    @tag fixtures: [:alice, :bob]
    test "merge is single same address transaction", %{alice: alice, bob: bob} do
      fees =
        create_recovered(
          [{1, 0, 0, alice}, {1, 0, 1, alice}, {2, 0, 0, alice}],
          @eth,
          [{alice, 5}, {bob, 5}]
        )
        |> for_tx(@fees)

      assert not covered?(%{@eth => 10}, %{@eth => 10}, fees)
    end
  end
end
