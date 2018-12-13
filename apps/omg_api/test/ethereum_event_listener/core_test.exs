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

  @finality_margin 10

  defp create_state, do: create_state(100)

  defp create_state(height, sync_mode) do
    Core.init(:event_listener_height, :event_listener, height, @finality_margin, sync_mode)
  end

  test "produces next ethereum height range to get events from" do
    state = create_state(100, :sync_with_coordinator)
    next_sync_height = 101

    {:get_events, {lower_bound, upper_bound}, state, [{:put, :event_listener_height, ^next_sync_height}]} =
      Core.get_events_height_range_for_next_sync(state, next_sync_height)

    assert next_sync_height == upper_bound + state.block_finality_margin
    assert lower_bound <= upper_bound

    {:dont_get_events, ^state} = Core.get_events_height_range_for_next_sync(state, next_sync_height)

    next_sync_height = next_sync_height + 1
    expected_lower_bound = upper_bound + 1

    assert {
             :get_events,
             {^expected_lower_bound, expected_upper_bound},
             state,
             [{:put, :event_listener_height, ^next_sync_height}]
           } = Core.get_events_height_range_for_next_sync(state, next_sync_height)

    assert next_sync_height == expected_upper_bound + state.block_finality_margin

    {:dont_get_events, ^state} = Core.get_events_height_range_for_next_sync(state, next_sync_height)
    assert expected_upper_bound < next_sync_height
  end

  test "restart allows to continue with proper bounds" do
    state = create_state(100, :sync_with_coordinator)
    next_sync_height = 105

    {:get_events, {lower_bound, upper_bound}, _state, [{:put, :event_listener_height, ^next_sync_height}]} =
      Core.get_events_height_range_for_next_sync(state, next_sync_height)

    assert lower_bound == 100 - @finality_margin + 1

    # simulate restart:
    state = create_state(next_sync_height, :sync_with_coordinator)

    next_sync_height = next_sync_height + 3
    expected_lower_bound = upper_bound + 1
    expected_upper_bound = next_sync_height - @finality_margin
    assert 3 == expected_upper_bound - expected_lower_bound + 1

    assert {
             :get_events,
             {^expected_lower_bound, ^expected_upper_bound},
             _,
             [{:put, :event_listener_height, ^next_sync_height}]
           } = Core.get_events_height_range_for_next_sync(state, next_sync_height)
  end
end
