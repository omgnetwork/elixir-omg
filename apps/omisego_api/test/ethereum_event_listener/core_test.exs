defmodule OmiseGO.API.EthereumEventListener.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.EthereumEventListener.Core

  deffixture initial_state() do
    %Core{block_finality_margin: 10, current_block_height: 100}
  end

  @tag fixtures: [:initial_state]
  test "produces next ethereum height to get events from", %{initial_state: state} do
    next_sync_height = 101
    {:get_events, events_block_height, state} = Core.next_events_block_height(state, next_sync_height)
    {:dont_get_events, ^state} = Core.next_events_block_height(state, next_sync_height)
    assert events_block_height < next_sync_height

    next_sync_height = next_sync_height + 1
    expected_block_height = events_block_height + 1
    {:get_events, ^expected_block_height, state} = Core.next_events_block_height(state, next_sync_height)
    {:dont_get_events, ^state} = Core.next_events_block_height(state, next_sync_height)
    assert expected_block_height < next_sync_height
  end
end
