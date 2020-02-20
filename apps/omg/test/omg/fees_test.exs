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

defmodule OMG.FeesTest do
  @moduledoc false

  use ExUnitFixtures
  use OMG.Fixtures
  use ExUnit.Case, async: true

  import OMG.TestHelper

  alias __MODULE__.DummyTransaction
  alias OMG.Fees

  doctest OMG.Fees

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @not_eth_1 <<1::size(160)>>

  @payment_tx_type OMG.WireFormatTypes.tx_type_for(:tx_payment_v1)

  @payment_fees %{
    @eth => [1],
    @not_eth_1 => [3]
  }

  @fees %{
    @payment_tx_type => @payment_fees
  }

  describe "check_if_covered/2" do
    test "returns :ok when given fees are 0 and :ignore_fees is passed" do
      assert Fees.check_if_covered(%{@eth => 0}, :ignore_fees) == :ok
    end

    test "returns :ok when given positive fees and :ignore_fees is passed" do
      assert Fees.check_if_covered(%{@eth => 1, @not_eth_1 => 2}, :ignore_fees) == :ok
    end

    test "returns :overpaying_fees when given positive fees and :no_fees_required is passed" do
      assert Fees.check_if_covered(%{@not_eth_1 => 0, @eth => 1}, :no_fees_required) == {:error, :overpaying_fees}
    end

    test "returns :ok when given fees are 0 and :no_fees_required is passed" do
      assert Fees.check_if_covered(%{@eth => 0}, :no_fees_required) == :ok
    end

    test "returns :ok when fees are exactly covered by one currency" do
      assert Fees.check_if_covered(%{@not_eth_1 => 3, @eth => 0}, @payment_fees) == :ok
    end

    test "returns :multiple_potential_currency_fees when multiple implicit fees are given" do
      assert Fees.check_if_covered(%{@eth => 2, @not_eth_1 => 2}, @payment_fees) ==
               {:error, :multiple_potential_currency_fees}
    end

    test "returns :fees_not_covered when no positive implicit fees given" do
      other_currency = <<2::160>>
      assert Fees.check_if_covered(%{other_currency => 0}, @payment_fees) == {:error, :fees_not_covered}
    end

    test "returns :fees_not_covered when the implicit fees currency does not match any of the supported fee currencies" do
      other_currency = <<2::160>>
      assert Fees.check_if_covered(%{other_currency => 100}, @payment_fees) == {:error, :fees_not_covered}
    end

    test "returns :fees_not_covered when fees do not cover the fee price" do
      assert Fees.check_if_covered(%{@not_eth_1 => 1}, @payment_fees) == {:error, :fees_not_covered}
    end

    test "returns :overpaying_fees when fees cover more than the fee price" do
      assert Fees.check_if_covered(%{@not_eth_1 => 4}, @payment_fees) == {:error, :overpaying_fees}
    end

    @tag fixtures: [:alice, :bob]
    test "returns :ok when one input is dedicated for fee payment, and outputs are other tokens",
         %{alice: alice, bob: bob} do
      # a token that we don't allow to pay the fees in
      other_token = <<2::160>>

      # it is presumed that one input is `other_token` (to cover outputs) and the other input is `@not_eth_1` to cover
      # the fee only. Note that `@not_eth_1` doesn't appear in the outputs
      transaction =
        create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, other_token, 5}, {alice, other_token, 5}])

      fees = Fees.for_transaction(transaction, @fees)
      # here we tell `Fees` that 3 `@not_eth_1` was sent to cover the fee
      assert Fees.check_if_covered(%{@not_eth_1 => 3, other_token => 0}, fees) == :ok
    end
  end

  describe "for_transaction/2" do
    @tag fixtures: [:alice, :bob]
    test "returns the fee map when not a merge transaction", %{alice: alice, bob: bob} do
      transaction = create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 3}])
      assert Fees.for_transaction(transaction, @fees) == @payment_fees
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

    test "returns an empty hash when given an unsuported tx type" do
      transaction = %OMG.State.Transaction.Recovered{
        signed_tx: %OMG.State.Transaction.Signed{raw_tx: DummyTransaction.new(), sigs: []},
        tx_hash: "",
        witnesses: [],
        signed_tx_bytes: ""
      }

      assert Fees.for_transaction(transaction, @fees) == %{}
    end

    @tag fixtures: [:alice, :bob]
    test "returns an empty hash when given invalid tx type", %{alice: alice, bob: bob} do
      fees = %{
        999 => %{
          @eth => %{
            amount: 1,
            subunit_to_unit: 1_000_000_000_000_000_000,
            pegged_amount: 4,
            pegged_currency: "USD",
            pegged_subunit_to_unit: 100,
            updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
          }
        }
      }

      transaction = create_recovered([{1, 0, 0, alice}], @eth, [{bob, 6}, {alice, 3}])
      assert Fees.for_transaction(transaction, fees) == %{}
    end
  end

  defmodule DummyTransaction do
    defstruct []

    def new(), do: %__MODULE__{}
  end
end
