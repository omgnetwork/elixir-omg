# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.API.EthereumEventListener.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.API.EthereumEventListener.Core
  alias OMG.API.RootChainCoordinator.SyncData

  @finality_margin 2
  @db_key :db_key
  @service_name :name
  @request_max_size 5

  defp create_state(height) do
    Core.init(@db_key, @service_name, height, @finality_margin, @request_max_size)
  end

  defp event(height), do: %{eth_height: height}

  defp assert_range({:get_events, range, state}, range2) do
    assert range == range2
    state
  end

  defp assert_range({:dont_get_events, state}, :dont_get_events), do: state

  defp assert_events({:ok, events, db_update, new_state}, events2, db_update2) do
    assert {events, db_update} == {events2, db_update2}
    new_state
  end

  test "produces next ethereum height range to get events from" do
    create_state(0)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 5, root_chain: 10})
    |> assert_range({1, 6})
    |> Core.get_events_range_for_download(%SyncData{sync_height: 7, root_chain: 10})
    |> assert_range({7, 10})
    |> Core.get_events_range_for_download(%SyncData{sync_height: 7, root_chain: 10})
    |> assert_range(:dont_get_events)
  end

  test "restart allows to continue with proper bounds" do
    create_state(1)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 3, root_chain: 10})
    |> assert_range({2, 7})
    |> Core.add_new_events([event(2), event(3), event(4), event(5), event(7)])
    |> Core.get_events_range_for_download(%SyncData{sync_height: 5, root_chain: 10})
    |> assert_range(:dont_get_events)
    |> Core.get_events(5)
    |> assert_events([event(2), event(3)], [{:put, @db_key, 3}])

    create_state(3)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 7, root_chain: 10})
    |> assert_range({4, 9})
    |> Core.add_new_events([event(4), event(5), event(7), event(9)])
    |> Core.get_events(7)
    |> assert_events([event(4), event(5)], [{:put, @db_key, 5}])
  end
end
