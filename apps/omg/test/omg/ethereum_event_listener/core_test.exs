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

defmodule OMG.EthereumEventListener.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.Configuration
  alias OMG.EthereumEventListener.Core
  alias OMG.RootChainCoordinator.SyncGuide

  @db_key :db_key
  @service_name :name
  @request_max_size 5

  test "respects request_max_size argument" do
    create_state(0, request_max_size: 10)
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 20, root_chain_height: 10})
    |> assert_range({1, 10})

    create_state(0, request_max_size: 10)
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 11, root_chain_height: 10})
    |> assert_range({1, 10})

    create_state(0, request_max_size: 10)
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 10, root_chain_height: 10})
    |> assert_range({1, 10})
  end

  test "event range is capped at the SyncGuide sync_height" do
    # if request_max_size is taken into account it would
    # push the event range above the threshold  and would remove the reorg protection
    create_state(0, request_max_size: 2)
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 1, root_chain_height: 10})
    |> assert_range({1, 1})
  end

  test "get events range is capped at request_max_size and the events range returned is less then SyncGuide sync_height" do
    create_state(0, request_max_size: 2)
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 4, root_chain_height: 10})
    |> assert_range({1, 2})
  end

  test "works well close to zero" do
    0
    |> create_state()
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 1, root_chain_height: 10})
    |> assert_range({1, 1})
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 8, root_chain_height: 10})
    |> assert_range({2, 6})

    0
    |> create_state()
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 9, root_chain_height: 10})
    |> assert_range({1, 5})
  end

  test "always returns correct height to check in" do
    state =
      0
      |> create_state()
      |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 1, root_chain_height: 10})
      |> assert_range({1, 1})

    assert state.synced_height == 1
  end

  test "produces next ethereum height range to get events from" do
    0
    |> create_state()
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 5, root_chain_height: 10})
    |> assert_range({1, 5})
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 5, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 7, root_chain_height: 10})
    |> assert_range({6, 7})
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 7, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
  end

  test "if synced requested higher than root chain height" do
    # doesn't make too much sense, but still should work well
    0
    |> create_state()
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 5, root_chain_height: 5})
    |> assert_range({1, 5})
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 7, root_chain_height: 5})
    |> assert_range({6, 7})
  end

  test "will be eager to get more events, even if none are pulled at first. All will be returned" do
    0
    |> create_state()
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 2, root_chain_height: 2})
    |> assert_range({1, 2})
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 4, root_chain_height: 4})
    |> assert_range({3, 4})
  end

  test "restart allows to continue with proper bounds" do
    1
    |> create_state()
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 4, root_chain_height: 10})
    |> assert_range({2, 4})
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 4, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 5, root_chain_height: 10})
    |> assert_range({5, 5})

    3
    |> create_state()
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 3, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 5, root_chain_height: 10})
    |> assert_range({4, 5})

    3
    |> create_state()
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 7, root_chain_height: 10})
    |> assert_range({4, 7})
  end

  test "wont move over if not allowed by sync_height" do
    5
    |> create_state()
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 6, root_chain_height: 10})
    |> assert_range({6, 6})
  end

  test "can get an empty events list when events too fresh" do
    4
    |> create_state()
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 6, root_chain_height: 10})
    |> assert_range({5, 6})
  end

  test "persists/checks in eth_height without margins substracted, and never goes negative" do
    create_state(0, request_max_size: 10)
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 6, root_chain_height: 10})
    |> assert_range({1, 6})
  end

  test "tolerates being asked to sync on height already synced" do
    create_state(5)
    |> Core.calc_events_range_set_height(%SyncGuide{sync_height: 1, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
  end

  defp create_state(height, opts \\ []) do
    request_max_size = Keyword.get(opts, :request_max_size, @request_max_size)
    # this assert is meaningful - currently we want to explicitly check_in the height read from DB
    assert {state, ^height} =
             Core.init(
               @db_key,
               @service_name,
               height,
               Configuration.ethereum_events_check_interval_ms(),
               request_max_size
             )

    state
  end

  defp assert_range({range, state}, expect) do
    assert range == expect
    state
  end
end
