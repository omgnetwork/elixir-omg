defmodule OmiseGO.API.EthereumEventListener.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.EthereumEventListener.Core

  @max_blocks_in_fetch 5
  @block_finality_margin 10
  @get_events_interval 60_000

  deffixture initial_state(), do:
    %Core{
      last_event_block: 0,
      block_finality_margin: @block_finality_margin,
      max_blocks_in_fetch: @max_blocks_in_fetch,
      get_events_inerval: @get_events_interval
    }

  @tag fixtures: [:initial_state]
  test "consecutive ranges of blocks are produced until there are no more finalized blocks",
    %{initial_state: state} do
    block_from = 1
    eth_height = 2 * @max_blocks_in_fetch + @block_finality_margin

    {:ok, state, 0, ^block_from, block_to} = Core.get_events_block_range(state, eth_height)
    assert block_to >= block_from

    {:ok, state, @get_events_interval, block_from_2, block_to_2} =
      Core.get_events_block_range(state, eth_height)
    assert block_from_2 == block_to + 1
    assert block_to_2 >= block_from_2

    {:no_blocks_with_event, ^state, @get_events_interval} =
      Core.get_events_block_range(state, eth_height)
  end

  @tag fixtures: [:initial_state]
  test "produced range of blocks respect increasing Ethereum height",
    %{initial_state: state} do
    block_from = 1
    eth_height = @max_blocks_in_fetch + @block_finality_margin
    {:ok, state, @get_events_interval, ^block_from, block_to} =
        Core.get_events_block_range(state, eth_height)

    eth_height_2 = eth_height + 1
    {:ok, _, @get_events_interval, block_from_2, block_to_2} =
        Core.get_events_block_range(state, eth_height_2)
    assert block_from_2 == block_to + 1
    assert block_to_2 == block_from_2
  end

  @tag fixtures: [:initial_state]
  test "no new ranges of blocks are produced when Ethereum height decreases",
    %{initial_state: state} do
      eth_height = @max_blocks_in_fetch + @block_finality_margin
      {:ok, state, @get_events_interval, _, _} =
          Core.get_events_block_range(state, eth_height)

      eth_height_2 = eth_height - 1
      {:no_blocks_with_event, ^state, @get_events_interval} =
        Core.get_events_block_range(state, eth_height_2)
  end
end
