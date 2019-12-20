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
  @not_eth_1 <<1::size(160)>>
  @not_eth_2 <<2::size(160)>>

  @payment_tx_type OMG.WireFormatTypes.tx_type_for(:tx_payment_v1)

  @payment_fees %{
    @eth => %{
      amount: 1,
      subunit_to_unit: 1_000_000_000_000_000_000,
      pegged_amount: 4,
      pegged_currency: "USD",
      pegged_subunit_to_unit: 100,
      updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
    },
    @not_eth_1 => %{
      amount: 3,
      subunit_to_unit: 1000,
      pegged_amount: 4,
      pegged_currency: "USD",
      pegged_subunit_to_unit: 100,
      updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
    }
  }

  @fees %{
    @payment_tx_type => @payment_fees
  }

  describe "covered?/2" do
    test "does not check the fees when :no_fees_required is passed" do
      assert Fees.covered?(%{@eth => 0}, :no_fees_required)
    end

    test "returns true when fees are covered by another currency" do
      assert Fees.covered?(%{@not_eth_1 => 5}, @payment_fees)
    end

    test "returns true when multiple implicit fees are given and fee is covered by eth" do
      assert Fees.covered?(%{@eth => 2, @not_eth_1 => 2}, @payment_fees)
    end

    test "returns true when multiple implicit fees are given and fee is covered by another currency" do
      assert Fees.covered?(%{@eth => 0.5, @not_eth_1 => 4}, @payment_fees)
    end

    test "returns false when the implicit fees currency does not match any of the supported fee currencies" do
      other_currency = <<2::160>>
      refute Fees.covered?(%{other_currency => 100}, @payment_fees)
    end

    @tag fixtures: [:alice, :bob]
    test "returns true when one input is dedicated for fee payment, and outputs are other tokens",
         %{alice: alice, bob: bob} do
      # a token that we don't allow to pay the fees in
      other_token = <<2::160>>

      # it is presumed that one input is `other_token` (to cover outputs) and the other input is `@not_eth_1` to cover
      # the fee only. Note that `@not_eth_1` doesn't appear in the outputs
      transaction =
        create_recovered([{1, 0, 0, alice}, {2, 0, 0, alice}], [{bob, other_token, 5}, {alice, other_token, 5}])

      fees = Fees.for_transaction(transaction, @fees)
      # here we tell `Fees` that 5 `@not_eth_1` was sent to cover the fee
      assert Fees.covered?(%{@not_eth_1 => 5, other_token => 0}, fees)
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
        signed_tx: %OMG.State.Transaction.Signed{raw_tx: %OMG.TransactionHelper.Dummy{}, sigs: []},
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

  describe "filter_fees/2" do
    test "does not filter tx_type when given an empty list" do
      assert Fees.filter_fees(@fees, [], []) == {:ok, @fees}
    end

    test "does not filter tx_type when given a nil value" do
      assert Fees.filter_fees(@fees, nil, []) == {:ok, @fees}
    end

    test "does not filter currencies when given an empty list" do
      assert Fees.filter_fees(@fees, [], []) == {:ok, @fees}
    end

    test "does not filter currencies when given a nil value" do
      assert Fees.filter_fees(@fees, [], nil) == {:ok, @fees}
    end

    test "filter fees by currency given a list of currencies" do
      fees =
        @fees
        |> Map.put(2, @payment_fees)
        |> Map.put(
          3,
          %{
            @not_eth_2 => %{
              amount: 3,
              subunit_to_unit: 1000,
              pegged_amount: 4,
              pegged_currency: "USD",
              pegged_subunit_to_unit: 100,
              updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
            }
          }
        )

      assert Fees.filter_fees(fees, [], [@eth]) ==
               {:ok,
                %{
                  @payment_tx_type => Map.take(@payment_fees, [@eth]),
                  2 => Map.take(@payment_fees, [@eth]),
                  3 => %{}
                }}

      assert Fees.filter_fees(fees, [], [@not_eth_2]) == {:ok, %{@payment_tx_type => %{}, 2 => %{}, 3 => fees[3]}}
    end

    test "filter fees by tx_type when given a list of tx_types" do
      fees =
        @fees
        |> Map.put(2, @payment_fees)
        |> Map.put(
          3,
          %{
            @not_eth_2 => %{
              amount: 3,
              subunit_to_unit: 1000,
              pegged_amount: 4,
              pegged_currency: "USD",
              pegged_subunit_to_unit: 100,
              updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
            }
          }
        )

      assert Fees.filter_fees(fees, [1, 2], []) == {:ok, Map.drop(fees, [3])}
    end

    test "filter fees by both tx_type and currencies" do
      fees =
        @fees
        |> Map.put(2, @payment_fees)
        |> Map.put(
          3,
          %{
            @not_eth_2 => %{
              amount: 3,
              subunit_to_unit: 1000,
              pegged_amount: 4,
              pegged_currency: "USD",
              pegged_subunit_to_unit: 100,
              updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
            }
          }
        )

      assert Fees.filter_fees(fees, [1, 2], [@eth]) ==
               {:ok,
                %{
                  @payment_tx_type => Map.take(@payment_fees, [@eth]),
                  2 => Map.take(@payment_fees, [@eth])
                }}
    end

    test "returns an error when given an unsupported currency" do
      other_token = <<9::160>>
      assert Fees.filter_fees(@fees, [], [other_token]) == {:error, :currency_fee_not_supported}
    end

    test "returns an error when given an unsupported tx_type" do
      tx_type = 99_999
      assert Fees.filter_fees(@fees, [tx_type], []) == {:error, :tx_type_not_supported}
    end
  end
end
