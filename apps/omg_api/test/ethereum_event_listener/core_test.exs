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

  deffixture initial_state() do
    %Core{
      block_finality_margin: 10,
      service_name: :event_listener,
      synced_height_update_key: :event_listener_height,
      next_event_height_lower_bound: 80,
      synced_height: 100
    }
  end

  @tag fixtures: [:initial_state]
  test "produces next ethereum height range to get events from", %{initial_state: state} do
    next_sync_height = 101

    {:get_events, {lower_bound, upper_bound}, state, [{:put, :event_listener_height, synced_height}]} =
      Core.get_events_height_range_for_next_sync(state, next_sync_height)

    assert synced_height == upper_bound
    assert lower_bound < upper_bound

    {:dont_get_events, ^state} = Core.get_events_height_range_for_next_sync(state, next_sync_height)

    next_sync_height = next_sync_height + 1
    expected_lower_bound = upper_bound + 1

    {
      :get_events,
      {^expected_lower_bound, expected_upper_bound},
      state,
      [{:put, :event_listener_height, synced_height}]
    } = Core.get_events_height_range_for_next_sync(state, next_sync_height)

    assert synced_height == expected_upper_bound

    {:dont_get_events, ^state} = Core.get_events_height_range_for_next_sync(state, next_sync_height)
    assert expected_upper_bound < next_sync_height
  end
end
