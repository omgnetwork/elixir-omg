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

defmodule OMG.Watcher.ExitValidator.CoreTest do
  use ExUnit.Case, async: true

  alias OMG.Watcher.ExitValidator.Core

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
