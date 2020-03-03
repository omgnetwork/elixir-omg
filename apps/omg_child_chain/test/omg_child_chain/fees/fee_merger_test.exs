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
defmodule OMG.ChildChain.Fees.FeeMergerTest do
  @moduledoc false
  use ExUnitFixtures
  use ExUnit.Case, async: true
  alias OMG.ChildChain.Fees.FeeMerger
  alias OMG.Eth

  doctest FeeMerger

  @eth Eth.zero_address()
  @not_eth <<1::size(160)>>

  @valid_current %{
    1 => %{
      @eth => %{
        amount: 1,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      },
      @not_eth => %{
        amount: 2,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      }
    }
  }

  @valid_previous %{
    1 => %{
      @eth => %{
        amount: 3,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      },
      @not_eth => %{
        amount: 4,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      }
    }
  }

  describe "merge_specs/2" do
    test "merges previous and current specs with distinct amounts" do
      assert %{1 => %{@eth => [1, 3], @not_eth => [2, 4]}} == FeeMerger.merge_specs(@valid_current, @valid_previous)
    end

    test "merges ignore amounts when they are the same" do
      previous =
        @valid_previous
        |> Kernel.put_in([1, @eth, :amount], 1)
        |> Kernel.put_in([1, @not_eth, :amount], 2)

      assert %{1 => %{@eth => [1], @not_eth => [2]}} == FeeMerger.merge_specs(@valid_current, previous)
    end

    test "merges correctly with nil previous" do
      assert %{1 => %{@eth => [1], @not_eth => [2]}} == FeeMerger.merge_specs(@valid_current, nil)
    end

    test "merges supports new tokens in previous" do
      new_token = <<2::size(160)>>

      new_token_fees = %{
        amount: 5,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      }

      previous = Kernel.put_in(@valid_previous, [1, new_token], new_token_fees)

      assert %{1 => %{@eth => [1, 3], @not_eth => [2, 4], new_token => [5]}} ==
               FeeMerger.merge_specs(@valid_current, previous)
    end

    test "merges supports new tokens in current" do
      new_token = <<2::size(160)>>

      new_token_fees = %{
        amount: 5,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      }

      current = Kernel.put_in(@valid_current, [1, new_token], new_token_fees)

      assert %{1 => %{@eth => [1, 3], @not_eth => [2, 4], new_token => [5]}} ==
               FeeMerger.merge_specs(current, @valid_previous)
    end

    test "merges supports new type in previous" do
      previous = Map.put(@valid_previous, 2, Map.get(@valid_previous, 1))

      assert %{1 => %{@eth => [1, 3], @not_eth => [2, 4]}, 2 => %{@eth => [3], @not_eth => [4]}} ==
               FeeMerger.merge_specs(@valid_current, previous)
    end

    test "merges supports new type in current" do
      current = Map.put(@valid_current, 2, Map.get(@valid_current, 1))

      assert %{1 => %{@eth => [1, 3], @not_eth => [2, 4]}, 2 => %{@eth => [1], @not_eth => [2]}} ==
               FeeMerger.merge_specs(current, @valid_previous)
    end
  end
end
