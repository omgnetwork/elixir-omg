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

  doctest OMG.Fees

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @not_eth <<1::size(160)>>

  @fees %{
    @eth => %{
      amount: 1,
      subunit_to_unit: 1_000_000_000_000_000_000,
      pegged_amount: 4,
      pegged_currency: "USD",
      pegged_subunit_to_unit: 100,
      updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
    },
    @not_eth => %{
      amount: 3,
      subunit_to_unit: 1000,
      pegged_amount: 4,
      pegged_currency: "USD",
      pegged_subunit_to_unit: 100,
      updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
    }
  }

  describe "covered?/2" do
    test "does not check the fees when :no_fees_required is passed" do
      assert Fees.covered?(%{@eth => 0}, :no_fees_required)
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

    @tag fixtures: [:alice, :bob]
    test "returns true when one input is dedicated for fee payment, and outputs are other tokens",
         %{alice: alice, bob: bob} do
      # a token that we don't allow to pay the fees in
      other_token = <<2::160>>

      # it is presumed that one input is `other_token` (to cover outputs) and the other input is `@not_eth` to cover
      # the fee only. Note that `@not_eth` doesn't appear in the outputs
      transaction =
        create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, other_token, 5}, {alice, other_token, 5}])

      fees = Fees.for_transaction(transaction, @fees)
      # here we tell `Fees` that 5 `@not_eth` was sent to cover the fee
      assert Fees.covered?(%{@not_eth => 5, other_token => 0}, fees)
    end
  end

  describe "for_transaction/2" do
    @tag fixtures: [:alice, :bob]
    test "returns the fee map when not a merge transaction", %{alice: alice, bob: bob} do
      transaction = create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 3}])
      assert Fees.for_transaction(transaction, @fees) == @fees
    end

    @tag fixtures: [:alice]
    test "returns :no_fees_required for merge transactions",
         %{alice: alice} do
      transaction = create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], @eth, [{alice, 10}])
      assert Fees.for_transaction(transaction, @fees) == :no_fees_required
    end

    @tag fixtures: [:alice]
    test "returns :no_fees_required for valid merge transactions with multiple inputs/ouputs",
         %{alice: alice} do
      transaction =
        create_recovered(
          [{1, 0, 0, alice}, {1, 0, 1, alice}, {2, 0, 0, alice}, {2, 1, 0, alice}],
          [{alice, @eth, 10}, {alice, @eth, 10}]
        )

      assert Fees.for_transaction(transaction, @fees) == :no_fees_required
    end
  end

  describe "filter_fees/2" do
    test "does not filter when an empty list is passed" do
      assert Fees.filter_fees(@fees, []) == {:ok, @fees}
    end

    test "filter fees given a list of currencies" do
      assert Fees.filter_fees(@fees, [@eth]) == {:ok, Map.drop(@fees, [@not_eth])}
    end

    test "returns an error when given an unsupported currency" do
      other_token = <<2::160>>
      assert Fees.filter_fees(@fees, [other_token]) == {:error, :currency_fee_not_supported}
    end
  end
end
