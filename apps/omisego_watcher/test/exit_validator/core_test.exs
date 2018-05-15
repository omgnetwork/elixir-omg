defmodule OmiseGOWatcher.ExitValidator.CoreTest do
  use ExUnit.Case, async: true

  alias OmiseGOWatcher.ExitValidator.Core

  test "lower bound of a block range does not exceed synced Ethereum height" do
    state = %Core{last_exit_block_height: 0, update_key: :update_key}
    {1, 10, state, [{:put, :update_key, 10}]} = Core.get_exits_block_range(state, 10)
    assert :empty_range == Core.get_exits_block_range(state, 10)
    {11, 11, _, [{:put, :update_key, 11}]} = Core.get_exits_block_range(state, 11)
  end

  test "margin over synced Ethereum height is respected" do
    state = %Core{last_exit_block_height: 0, update_key: :update_key, margin_on_synced_block: 5}
    {1, 5, state, [{:put, :update_key, 5}]} = Core.get_exits_block_range(state, 10)
    assert :empty_range == Core.get_exits_block_range(state, 10)
  end
end
