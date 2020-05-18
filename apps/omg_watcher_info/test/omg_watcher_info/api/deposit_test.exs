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

defmodule OMG.WatcherInfo.API.DepositTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.WatcherInfo.Fixtures

  import OMG.WatcherInfo.Factory

  alias OMG.Utils.Paginator
  alias OMG.WatcherInfo.API
  alias OMG.WatcherInfo.DB

  describe "get_deposits/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a paginator with a list of deposits" do
      _ = insert(:ethevent, event_type: :deposit)
      _ = insert(:ethevent, event_type: :deposit)
      _ = insert(:ethevent, event_type: :non_deposit)

      constraints = []
      results = API.Deposit.get_deposits(constraints)

      assert %Paginator{} = results
      assert length(results.data) == 2
      assert Enum.all?(results.data, fn ethevent -> %DB.EthEvent{event_type: :deposit} = ethevent end)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns a paginator according to the provided paginator constraints" do
      _ = insert(:ethevent, event_type: :deposit)
      _ = insert(:ethevent, event_type: :deposit)
      _ = insert(:ethevent, event_type: :deposit)

      assert [page: 1, limit: 2] |> API.Deposit.get_deposits() |> Map.get(:data) |> length() == 2
      assert [page: 2, limit: 2] |> API.Deposit.get_deposits() |> Map.get(:data) |> length() == 1
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns results filtered by address when given an address constraint" do
      owner_1 = <<1::160>>
      owner_2 = <<2::160>>

      deposit_output_1 = build(:txoutput, %{owner: owner_1})
      deposit_output_2 = build(:txoutput, %{owner: owner_2})

      _ = insert(:ethevent, event_type: :deposit, txoutputs: [deposit_output_1])
      _ = insert(:ethevent, event_type: :deposit, txoutputs: [deposit_output_2])

      constraint = [address: owner_1]
      result = API.Deposit.get_deposits(constraint)

      assert %Paginator{data: [%DB.EthEvent{} = deposit]} = result
      assert deposit |> Map.get(:txoutputs) |> Enum.at(0) |> Map.get(:owner) == owner_1
    end
  end
end
