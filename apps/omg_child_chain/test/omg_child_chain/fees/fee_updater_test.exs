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

  {:ok, updated_at, _} = DateTime.from_iso8601("2019-01-01T10:10:00+00:00")

  @fee_spec %{
    1 => %{
      @eth => %{
        amount: 100,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: updated_at
      },
      @not_eth => %{
        amount: 100,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: updated_at
      }
    }
  }

  describe "can_update/4" do
    test "no changes when stored and fetched fees are the same" do
      assert :no_changes ==
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {100, @fee_spec},
                 0,
                 10
               )
    end

    test "always updates insignificant change when time passed" do
      fetched = put_in(@fee_spec[1][@eth][:amount], 101)

      assert {:ok, {10, ^fetched}} =
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {10, fetched},
                 25,
                 5
               )
    end

    test "updates when token amount raises above tolerance level" do
      fetched = put_in(@fee_spec[1][@eth][:amount], 120)

      assert {:ok, {10, ^fetched}} =
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {10, fetched},
                 20,
                 100
               )
    end

    test "updates when token amount decreases above tolerance level" do
      fetched = put_in(@fee_spec[1][@eth][:amount], 80)

      assert {:ok, {10, ^fetched}} =
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {10, fetched},
                 20,
                 100
               )
    end

    test "no updates when token amount raises below tolerance level" do
      fetched = put_in(@fee_spec[1][@eth][:amount], 119)

      assert :no_changes =
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {10, fetched},
                 20,
                 100
               )
    end

    test "updates when token amount drop below tolerance level" do
      fetched = put_in(@fee_spec[1][@eth][:amount], 81)

      assert :no_changes =
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {10, fetched},
                 20,
                 100
               )
    end

    test "always updates when stored and fetched specs differs on tx type" do
      fetched = %{2 => @fee_spec[1]}

      assert {:ok, {10, ^fetched}} =
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {10, fetched},
                 20,
                 100
               )
    end

    test "always updates when stored and fetched specs differs on token" do
      fetched = %{1 => Map.delete(@fee_spec[1], @eth)}

      assert {:ok, {10, ^fetched}} =
               FeeUpdater.can_update(
                 {0, @fee_spec},
                 {10, fetched},
                 20,
                 100
               )
    end

    test "always updates when stored and fetched specs differs on token (drop support of token)" do
      stored = Map.put_new(@fee_spec, 2, @fee_spec[1])
      fetched = %{1 => @fee_spec[1], 2 => Map.delete(@fee_spec[1], @eth)}

      assert {:ok, {10, ^fetched}} =
               FeeUpdater.can_update(
                 {0, stored},
                 {10, fetched},
                 20,
                 100
               )
    end

    test "always updates when stored and fetched specs differs on token (add support of token)" do
      stored = Map.put_new(@fee_spec, 2, Map.delete(@fee_spec[1], @eth))
      fetched = %{1 => @fee_spec[1], 2 => @fee_spec[1]}

      assert {:ok, {10, ^fetched}} =
               FeeUpdater.can_update(
                 {0, stored},
                 {10, fetched},
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

      stored = Map.put_new(@fee_spec, 2, update)
      fetched = %{1 => stored[2], 2 => stored[1]}

      assert :no_changes =
               FeeUpdater.can_update(
                 {0, stored},
                 {10, fetched},
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

      stored = Map.put_new(@fee_spec, 2, update)

      # lowers not_eth to exceed tolerance
      cheaper_fees = put_in(stored[1], [@not_eth, :amount], 88)
      fetched = %{1 => stored[2], 2 => cheaper_fees}

      assert {:ok, {10, ^fetched}} =
               FeeUpdater.can_update(
                 {0, stored},
                 {10, fetched},
                 20,
                 100
               )
    end
  end
end
