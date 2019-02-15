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

  defp assert_range({:get_events, range, state}, expect) do
    assert range == expect
    state
  end

  defp assert_range({:dont_fetch_events, state}, expect) do
    assert :dont_fetch_events == expect
    state
  end

  defp assert_events(response, opts) do
    expected_check_in_and_db = Keyword.get(opts, :check_in_and_db)
    expected_events = Keyword.get(opts, :events)
    assert {:ok, events, [{:put, @db_key, check_in_and_db}], check_in_and_db, new_state} = response
    if expected_events, do: assert(expected_events == events)
    if expected_check_in_and_db, do: assert(expected_check_in_and_db == check_in_and_db)
    new_state
  end

  test "range moved by finality_margin" do
    Core.init(@db_key, @service_name, _height = 0, _finality_margin = 5, _request_max_size = 100)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 1, root_chain_height: 10})
    |> assert_range({1, 5})
  end

  test "max request size respected" do
    Core.init(@db_key, @service_name, _height = 0, _finality_margin = 5, _request_max_size = 2)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 1, root_chain_height: 10})
    |> assert_range({1, 2})
  end

  test "max request size too small" do
    assert {:error, :invalid_init} =
             Core.init(@db_key, @service_name, _height = 5, _finality_margin = 2, _request_max_size = 0)
  end

  test "works well close to zero" do
    create_state(0)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 0, root_chain_height: 10})
    |> assert_range({1, 5})
    |> Core.add_new_events([event(1), event(3), event(4), event(5)])
    |> Core.get_events(0)
    |> assert_events(events: [], check_in_and_db: 0)
    |> Core.get_events(1)
    |> assert_events(events: [], check_in_and_db: 1)
    |> Core.get_events(2)
    |> assert_events(events: [], check_in_and_db: 2)
    |> Core.get_events(3)
    |> assert_events(events: [event(1)], check_in_and_db: 3)
  end

  test "produces next ethereum height range to get events from" do
    create_state(0)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 5, root_chain_height: 10})
    |> assert_range({1, 5})
    |> Core.get_events_range_for_download(%SyncData{sync_height: 5, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 7, root_chain_height: 10})
    |> assert_range({6, 8})
    |> Core.get_events_range_for_download(%SyncData{sync_height: 7, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
  end

  test "works with no finality margin too" do
    Core.init(@db_key, @service_name, _height = 0, _finality_margin = 0, _request_max_size = 100)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 5, root_chain_height: 10})
    |> assert_range({1, 10})
    |> Core.get_events_range_for_download(%SyncData{sync_height: 5, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 7, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
  end

  test "if synced below finality margin, will pull those events" do
    create_state(1)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 3, root_chain_height: 5})
    |> assert_range({1, 3})
  end

  test "restart allows to continue with proper bounds" do
    create_state(1)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 4, root_chain_height: 10})
    |> assert_range({1, 5})
    |> Core.add_new_events([event(1), event(3), event(4), event(5)])
    |> Core.get_events_range_for_download(%SyncData{sync_height: 4, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
    |> Core.get_events(4)
    |> assert_events(events: [event(1)], check_in_and_db: 4)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 5, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
    |> Core.get_events(5)
    |> assert_events(events: [event(3)], check_in_and_db: 5)

    create_state(3)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 3, root_chain_height: 10})
    |> assert_range({2, 6})
    |> Core.add_new_events([event(4), event(5), event(7)])
    |> Core.get_events(3)
    |> assert_events(events: [], check_in_and_db: 3)

    create_state(3)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 7, root_chain_height: 10})
    |> assert_range({2, 6})
    |> Core.add_new_events([event(4), event(5), event(7)])
    |> Core.get_events(7)
    |> assert_events(events: [event(4), event(5)], check_in_and_db: 7)
  end

  test "can get multiple events from one height" do
    create_state(5)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 6, root_chain_height: 10})
    |> assert_range({4, 8})
    |> Core.add_new_events([event(4), event(4), event(5)])
    |> Core.get_events(6)
    |> assert_events(events: [event(4), event(4)], check_in_and_db: 6)
  end

  test "can get an empty events list when events too fresh" do
    create_state(5)
    |> Core.get_events_range_for_download(%SyncData{sync_height: 6, root_chain_height: 10})
    |> assert_range({4, 8})
    |> Core.add_new_events([event(5), event(5), event(6)])
    |> Core.get_events(6)
    |> assert_events(events: [], check_in_and_db: 6)
  end

  test "doesn't fail when getting events from empty" do
    create_state(1)
    |> Core.get_events(5)
    |> assert_events(events: [], check_in_and_db: 5)
  end

  test "persists/checks in eth_height without margins substracted, and never goes negative" do
    state =
      Core.init(@db_key, @service_name, 0, @finality_margin, 10)
      |> Core.get_events_range_for_download(%SyncData{sync_height: 6, root_chain_height: 12})
      |> assert_range({1, 10})
      |> Core.add_new_events([event(4), event(5), event(6), event(7)])

    for i <- 1..9, do: state |> Core.get_events(i) |> assert_events(check_in_and_db: i)
  end
end
