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

  import OMG.TestHelper

  alias OMG.Fees

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @not_eth <<1::size(160)>>

  @fees %{
    @eth => 1,
    @not_eth => 3
  }

  describe "covered?/2" do
    test "does not check the fees when :no_fees_transaction is passed" do
      assert Fees.covered?(%{@eth => 0}, :no_fees_transaction)
    end

    test "returns true when fees are covered by eth" do
      assert Fees.covered?(%{@eth => 2}, @fees)
    end

    test "returns true when fees are covered by another currency" do
      assert Fees.covered?(%{@not_eth => 5}, @fees)
    end

    test "returns true when multiple implicit fees are given and fee is covered by eth" do
      assert Fees.covered?(%{@eth => 2, @not_eth => 2}, @fees)
    end

    test "returns true when multiple implicit fees are given and fee is covered by another currency" do
      assert Fees.covered?(%{@eth => 0.5, @not_eth => 4}, @fees)
    end

    test "returns false when the implicit fees currency does not match any of the supported fee currencies" do
      other_currency = <<2::160>>
      refute Fees.covered?(%{other_currency => 100}, @fees)
    end

    # TODO: Fix this test?
    @tag fixtures: [:alice, :bob]
    test "returns true when one input is dedicated for fee payment", %{alice: alice, bob: bob} do
      other_token = <<2::160>>

      transaction =
        create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, other_token, 5}, {alice, other_token, 5}])

      fees = Fees.for_transaction(transaction, @fees)

      assert Fees.covered?(%{@not_eth => 5, other_token => 0}, fees)
    end
  end

  describe "for_transaction/2" do
    @tag fixtures: [:alice, :bob]
    test "returns the fee map when not a merge transaction (different addresses)", %{alice: alice, bob: bob} do
      transaction = create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 3}])
      assert Fees.for_transaction(transaction, @fees) == @fees
    end

    @tag fixtures: [:alice]
    test "returns :no_fees_transaction for merge transactions with single currency (eth) and same in/out address (free)",
         %{alice: alice} do
      transaction = create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], @eth, [{alice, 10}])
      assert Fees.for_transaction(transaction, @fees) == :no_fees_transaction
    end

    @tag fixtures: [:alice]
    test "returns :no_fees_transaction for valid merge transactions with multiple inputs/ouputs",
         %{alice: alice} do
      transaction =
        create_recovered(
          [{1, 0, 0, alice}, {1, 0, 1, alice}, {2, 0, 0, alice}, {2, 1, 0, alice}],
          [{alice, @eth, 10}, {alice, @eth, 10}]
        )

      assert Fees.for_transaction(transaction, @fees) == :no_fees_transaction
    end

    @tag fixtures: [:alice]
    test "returns :no_fees_transaction for merge transactions with single currency (not eth) and same in/out address (free)",
         %{alice: alice} do
      transaction = create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], @not_eth, [{alice, 10}])
      assert Fees.for_transaction(transaction, @fees) == :no_fees_transaction
    end

    @tag fixtures: [:alice]
    test "returns fees for merge transactions when not single currency", %{alice: alice} do
      transaction =
        create_recovered(
          [{1, 0, 0, alice}, {1, 0, 1, alice}, {2, 0, 0, alice}, {2, 1, 0, alice}],
          [{alice, @eth, 10}, {alice, @not_eth, 10}]
        )

      assert Fees.for_transaction(transaction, @fees) == @fees
    end
  end
end
