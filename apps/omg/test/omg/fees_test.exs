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

  # TODO: brittle test? why not test via public API (State.Core)?
  @tag fixtures: [:alice, :bob]
  test "Transactions covers the fee only in one currency accepted by the operator", %{alice: alice, bob: bob} do
    fees =
      create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 3}])
      |> for_tx(@fees)

    assert covered?(%{@eth => 1}, fees)

    fees =
      create_recovered([{1, 0, 0, alice}], @not_eth, [{bob, 4}, {alice, 3}])
      |> for_tx(@fees)

    assert covered?(%{@not_eth => 3}, fees)

    fees =
      create_recovered(
        [{1, 0, 0, alice}, {2, 0, 0, alice}],
        [{bob, @eth, 4}, {alice, @eth, 1}, {bob, @not_eth, 5}, {alice, @not_eth, 5}]
      )
      |> for_tx(@fees)

    assert covered?(%{@eth => 0, @not_eth => 3}, fees)
  end

  @tag fixtures: [:alice, :bob]
  test "Transaction which does not transfer any fee currency is object to fees", %{alice: alice, bob: bob} do
    other_token = <<2::160>>

    fees =
      create_recovered([{1, 0, 0, alice}], other_token, [{bob, 5}, {alice, 3}])
      |> for_tx(@fees)

    assert false == covered?(%{other_token => 3}, fees)
  end

  @tag fixtures: [:alice, :bob]
  test "Transaction can dedicate one input for a fee entirely, reducing to tx's outputs currencies is incorrect",
       %{alice: alice, bob: bob} do
    other_token = <<2::160>>

    fees =
      create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, other_token, 5}, {alice, other_token, 5}])
      |> for_tx(@fees)

    assert covered?(%{@not_eth => 5, other_token => 0}, fees)
  end

  describe "Merge transactions are free of cost" do
    @tag fixtures: [:alice]
    test "merging utxo erases the fee", %{alice: alice} do
      fees =
        create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], @not_eth, [{alice, 10}])
        |> for_tx(@fees)

      assert covered?(%{@not_eth => 0}, fees)
    end

    @tag fixtures: [:alice]
    test "merge is single currency transaction", %{alice: alice} do
      fees =
        create_recovered(
          [{1, 0, 0, alice}, {1, 0, 1, alice}, {2, 0, 0, alice}, {2, 1, 0, alice}],
          [{alice, @eth, 10}, {alice, @not_eth, 10}]
        )
        |> for_tx(@fees)

      assert not covered?(%{@eth => 0}, fees)
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

      assert not covered?(%{@eth => 0}, fees)
    end
  end
end
