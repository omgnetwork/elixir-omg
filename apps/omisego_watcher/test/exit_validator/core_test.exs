defmodule OmiseGOWatcher.ExitValidator.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGOWatcher.ExitValidator.Core

  deffixture initial_state(), do: %Core{last_exit_eth_height: 0}

  @tag fixtures: [:initial_state]
  test "lower bound of a block range does not ecceed synced Ethereum height",
    %{initial_state: state} do
      {1, 10, state, [{:put, :last_exit_block_height, 10}]} = Core.get_exits_block_range(state, 10)
      assert :empty_range == Core.get_exits_block_range(state, 10)
      {11, 11, _, [{:put, :last_exit_block_height, 11}]} = Core.get_exits_block_range(state, 11)
  end
end
