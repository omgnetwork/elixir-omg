defmodule OmiseGO.API.EthereumEventListener.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.EthereumEventListener.Core

  deffixture initial_state() do
    %Core{block_finality_margin: 10, next_event_height_lower_bound: 80, synced_height: 100}
  end

  @tag fixtures: [:initial_state]
  test "produces next ethereum height to get events from", %{initial_state: state} do
    next_sync_height = 101
    {:get_events, {lower_bound, upper_bound}, state} = Core.next_events_block_range(state, next_sync_height)
    {:dont_get_events, ^state} = Core.next_events_block_range(state, next_sync_height)
    assert lower_bound < upper_bound

    next_sync_height = next_sync_height + 1
    expected_lower_bound = upper_bound + 1

    {:get_events, {^expected_lower_bound, expected_upper_bound}, state} =
      Core.next_events_block_range(state, next_sync_height)

    {:dont_get_events, ^state} = Core.next_events_block_range(state, next_sync_height)
    assert expected_upper_bound < next_sync_height
  end
end
