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

defmodule OMG.Fees.FeeFilterTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias OMG.Fees.FeeFilter

  doctest OMG.Fees.FeeFilter

  @eth OMG.Eth.zero_address()
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
    @payment_tx_type => @payment_fees,
    2 => @payment_fees,
    3 => %{
      @not_eth_2 => %{
        amount: 3,
        subunit_to_unit: 1000,
        pegged_amount: 4,
        pegged_currency: "USD",
        pegged_subunit_to_unit: 100,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      }
    }
  }

  describe "filter/2" do
    test "does not filter tx_type when given an empty list" do
      assert FeeFilter.filter(@fees, [], []) == {:ok, @fees}
    end

    test "does not filter tx_type when given a nil value" do
      assert FeeFilter.filter(@fees, nil, []) == {:ok, @fees}
    end

    test "does not filter currencies when given an empty list" do
      assert FeeFilter.filter(@fees, [], []) == {:ok, @fees}
    end

    test "does not filter currencies when given a nil value" do
      assert FeeFilter.filter(@fees, [], nil) == {:ok, @fees}
    end

    test "filter fees by currency given a list of currencies" do
      assert FeeFilter.filter(@fees, [], [@eth]) ==
               {:ok,
                %{
                  @payment_tx_type => Map.take(@payment_fees, [@eth]),
                  2 => Map.take(@payment_fees, [@eth]),
                  3 => %{}
                }}

      assert FeeFilter.filter(@fees, [], [@not_eth_2]) == {:ok, %{@payment_tx_type => %{}, 2 => %{}, 3 => @fees[3]}}
    end

    test "filter fees by tx_type when given a list of tx_types" do
      assert FeeFilter.filter(@fees, [1, 2], []) == {:ok, Map.drop(@fees, [3])}
    end

    test "filter fees by both tx_type and currencies" do
      assert FeeFilter.filter(@fees, [1, 2], [@eth]) ==
               {:ok,
                %{
                  @payment_tx_type => Map.take(@payment_fees, [@eth]),
                  2 => Map.take(@payment_fees, [@eth])
                }}
    end

    test "returns an error when given an unsupported currency" do
      other_token = <<9::160>>
      assert FeeFilter.filter(@fees, [], [other_token]) == {:error, :currency_fee_not_supported}
    end

    test "returns an error when given an unsupported tx_type" do
      tx_type = 99_999
      assert FeeFilter.filter(@fees, [tx_type], []) == {:error, :tx_type_not_supported}
    end
  end
end
