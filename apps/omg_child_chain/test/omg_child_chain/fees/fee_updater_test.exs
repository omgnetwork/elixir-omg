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
defmodule OMG.ChildChain.Fees.FeeUpdaterTest do
  @moduledoc false
  use ExUnitFixtures
  use ExUnit.Case, async: true
  alias OMG.ChildChain.Fees.FeeUpdater
  alias OMG.Eth

  doctest FeeUpdater

  @eth Eth.zero_address()
  @not_eth <<1::size(160)>>

  @fee_spec %{
    1 => %{
      @eth => %{
        amount: 100,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      },
      @not_eth => %{
        amount: 100,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      }
    }
  }

  describe "can_update/4" do
    test "no changes when previous and actual fees are the same" do
      assert :no_changes ==
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {100, @fee_spec},
                 0,
                 10
               )
    end

    test "always updates insignificant change when time passed" do
      actual = put_in(@fee_spec[1][@eth][:amount], 101)

      assert {:ok, {10, ^actual}} =
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {10, actual},
                 25,
                 5
               )
    end

    test "updates when token amount raises above tolerance level" do
      actual = put_in(@fee_spec[1][@eth][:amount], 120)

      assert {:ok, {10, ^actual}} =
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {10, actual},
                 20,
                 100
               )
    end

    test "updates when token amount decreases above tolerance level" do
      actual = put_in(@fee_spec[1][@eth][:amount], 80)

      assert {:ok, {10, ^actual}} =
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {10, actual},
                 20,
                 100
               )
    end

    test "no updates when token amount raises below tolerance level" do
      actual = put_in(@fee_spec[1][@eth][:amount], 119)

      assert :no_changes =
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {10, actual},
                 20,
                 100
               )
    end

    test "updates when token amount drop belop tolerance level" do
      actual = put_in(@fee_spec[1][@eth][:amount], 81)

      assert :no_changes =
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {10, actual},
                 20,
                 100
               )
    end

    test "always update when specs differes on tx type" do
      actual = %{2 => @fee_spec[1]}

      assert {:ok, {10, ^actual}} =
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {10, actual},
                 20,
                 100
               )
    end

    test "multi-type update without significant changes result in no changes" do
      update =
        @fee_spec
        |> Map.get(1)
        |> put_in([@eth, :amount], 101)
        |> put_in([@not_eth, :amount], 111)

      prev = Map.put_new(@fee_spec, 2, update)
      actual = %{1 => prev[2], 2 => prev[1]}

      assert :no_changes =
               FeeUpdater.can_update(
                 {0, prev},
                 {10, actual},
                 20,
                 100
               )
    end

    test "update multi-type update when only one token amount above tolerance" do
      update =
        @fee_spec
        |> Map.get(1)
        |> put_in([@eth, :amount], 101)
        |> put_in([@not_eth, :amount], 111)

      prev = Map.put_new(@fee_spec, 2, update)

      # lowers not_eth to exceed tolerance
      cheaper_fees = put_in(prev[1], [@not_eth, :amount], 88)
      actual = %{1 => prev[2], 2 => cheaper_fees}

      assert {:ok, {10, ^actual}} =
               FeeUpdater.can_update(
                 {0, prev},
                 {10, actual},
                 20,
                 100
               )
    end
  end
end
