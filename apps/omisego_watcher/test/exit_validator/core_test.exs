defmodule OmiseGOWatcher.ExitValidator.CoreTest do
  use ExUnit.Case, async: true

  alias OmiseGOWatcher.ExitValidator.Core

  test "Ethereum block height to get exits from does not exceed synced Ethereum height" do
    state = %Core{last_exit_block_height: 0, synced_height: 0, update_key: :fast_validator_block_height}
    {10, state, [{:put, :fast_validator_block_height, 10}]} = Core.next_events_block_height(state, 10)
    assert :empty_range == Core.next_events_block_height(state, 10)
    {11, _, [{:put, :fast_validator_block_height, 11}]} = Core.next_events_block_height(state, 11)
  end

  test "margin over synced Ethereum height is respected" do
    state = %Core{
      last_exit_block_height: 0,
      synced_height: 0,
      update_key: :fast_validator_block_height,
      margin_on_synced_block: 5
    }

    {5, state, [{:put, :fast_validator_block_height, 5}]} = Core.next_events_block_height(state, 10)
    assert :empty_range == Core.next_events_block_height(state, 10)
  end
end
