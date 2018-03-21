defmodule OmiseGO.API.Depositor.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.Depositor.Core

  @max_blocks_in_fetch Application.get_env(:omisego_api, :depositor_max_block_range_in_deposits_query)
  @block_finality_margin Application.get_env(:omisego_api, :depositor_block_finality_margin)
  @get_deposits_interval Application.get_env(:omisego_api, :depositor_get_deposits_interval_ms)

  deffixture initial_state(), do: %Core{last_deposit_block: 0}

  @tag fixtures: [:initial_state]
  test "range of blocks to get deposits from is returned and there are no more finalized blocks",
    %{initial_state: state} do
    block_from = state.last_deposit_block + 1
    block_to = state.last_deposit_block + @max_blocks_in_fetch
    expected_state = %{state | last_deposit_block: block_to}

    assert {:ok, expected_state, @get_deposits_interval, block_from, block_to} ==
      Core.get_deposit_block_range(state, 10)
  end

  @tag fixtures: [:initial_state]
  test "range of blocks to get deposits from is empty when there are no new finalized blocks",
    %{initial_state: state} do
    assert {:no_deposits, state} ==
        Core.get_deposit_block_range(state, state.last_deposit_block + @block_finality_margin - 1)
  end

  @tag fixtures: [:initial_state]
  test "range of blocks to get deposits from is returned in parts",
    %{initial_state: state} do
    state
    |> assert_range(0)
    |> assert_range(@get_deposits_interval)
  end

  defp assert_range(state, expected_interval) do
    block_from = state.last_deposit_block + 1
    block_to = state.last_deposit_block + @max_blocks_in_fetch
    {:ok, state, ^expected_interval, ^block_from, ^block_to} = Core.get_deposit_block_range(state, 15)
    state
  end
end
