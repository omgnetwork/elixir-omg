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

defmodule OMGWatcher.ExitValidator.CoreTest do
  use ExUnit.Case, async: true

  alias OMGWatcher.ExitValidator.Core

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
