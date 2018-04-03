defmodule OmiseGO.API.Depositor.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.Depositor.Core

  @max_blocks_in_fetch Application.get_env(:omisego_api, :depositor_max_block_range_in_deposits_query)
  @block_finality_margin Application.get_env(:omisego_api, :depositor_block_finality_margin)
  @get_deposits_interval Application.get_env(:omisego_api, :depositor_get_deposits_interval_ms)

  deffixture initial_state(), do: %Core{last_deposit_block: 0}

  @tag fixtures: [:initial_state]
  test "consecutive ranges of blocks are produced until there are no more finalized blocks",
    %{initial_state: state} do
    block_from = 1
    eth_height = 2 * @max_blocks_in_fetch + @block_finality_margin

    {:ok, state, 0, ^block_from, block_to} = Core.get_deposit_block_range(state, eth_height)
    assert block_to >= block_from

    {:ok, state, @get_deposits_interval, block_from_2, block_to_2} =
      Core.get_deposit_block_range(state, eth_height)
    assert block_from_2 == block_to + 1
    assert block_to_2 >= block_from_2

    {:no_blocks_with_deposit, ^state, @get_deposits_interval} =
      Core.get_deposit_block_range(state, eth_height)
  end

  @tag fixtures: [:initial_state]
  test "produced range of blocks respect increasing Ethereum height",
    %{initial_state: state} do
    block_from = 1
    eth_height = @max_blocks_in_fetch + @block_finality_margin
    {:ok, state, @get_deposits_interval, ^block_from, block_to} =
        Core.get_deposit_block_range(state, eth_height)

    eth_height_2 = eth_height + 1
    {:ok, _, @get_deposits_interval, block_from_2, block_to_2} =
        Core.get_deposit_block_range(state, eth_height_2)
    assert block_from_2 == block_to + 1
    assert block_to_2 == block_from_2
  end

  @tag fixtures: [:initial_state]
  test "no new ranges of blocks are produced when Ethereum height decreases",
    %{initial_state: state} do
      eth_height = @max_blocks_in_fetch + @block_finality_margin
      {:ok, state, @get_deposits_interval, _, _} =
          Core.get_deposit_block_range(state, eth_height)

      eth_height_2 = eth_height - 1
      {:no_blocks_with_deposit, ^state, @get_deposits_interval} =
        Core.get_deposit_block_range(state, eth_height_2)
  end
end
