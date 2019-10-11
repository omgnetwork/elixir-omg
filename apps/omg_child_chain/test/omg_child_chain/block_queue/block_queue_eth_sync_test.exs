# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.BlockQueue.BlockQueueEthSyncTest do
  @moduledoc false
  use ExUnitFixtures
  use ExUnit.Case, async: true

  import OMG.ChildChain.BlockTestHelper

  alias OMG.ChildChain.BlockQueue.BlockQueueEthSync
  alias OMG.ChildChain.BlockQueue.BlockSubmission

  @child_block_interval 1000

  doctest OMG.ChildChain.BlockQueue.BlockQueueEthSync

  describe "set_mined_block_num/2" do
    test "sets the last block mined on parent chain when no higher formed child block" do
      state =
        BlockQueueEthSync.set_mined_block_num(
          %{
            blocks: get_blocks(6),
            child_block_interval: @child_block_interval,
            finality_threshold: 1,
            formed_child_block_num: 6_000,
            mined_child_block_num: nil
          },
          7_000
        )

      assert state.formed_child_block_num == 7_000
      assert state.mined_child_block_num == 7_000
    end

    test "keeps the highest formed child block when higher than last mined block" do
      state =
        BlockQueueEthSync.set_mined_block_num(
          %{
            blocks: get_blocks(6),
            child_block_interval: @child_block_interval,
            finality_threshold: 1,
            formed_child_block_num: 6_000,
            mined_child_block_num: nil
          },
          5_000
        )

      assert state.formed_child_block_num == 6_000
      assert state.mined_child_block_num == 5_000
    end

    test "removes 'confirmed' blocks (first four which are under the threshold in this case)" do
      state =
        BlockQueueEthSync.set_mined_block_num(
          %{
            blocks: get_blocks(10, 1),
            child_block_interval: @child_block_interval,
            finality_threshold: 5,
            formed_child_block_num: 10_000,
            mined_child_block_num: nil
          },
          8_000
        )

      # mined_child_block_num - child_block_interval * finality_threshold
      assert state.blocks == get_blocks(10, 4)
      assert state.formed_child_block_num == 10_000
      assert state.mined_child_block_num == 8_000
    end
  end

  describe "should_form_block?/2" do
    test "returns :do_form_block when blocks gap > minimal gap, block not empty, and not waiting for enqueue" do
      state = %{
        parent_height: 9382,
        last_enqueued_block_at_height: 9210,
        minimal_enqueue_block_gap: 1,
        wait_for_enqueue: false
      }

      assert BlockQueueEthSync.form_block_or_skip(state, false) ==
               {:do_form_block,
                %{
                  last_enqueued_block_at_height: 9210,
                  minimal_enqueue_block_gap: 1,
                  parent_height: 9382,
                  wait_for_enqueue: true
                }}
    end

    test "returns :do_not_form_block when the block is empty" do
      state = %{
        parent_height: 9382,
        last_enqueued_block_at_height: 9210,
        minimal_enqueue_block_gap: 1,
        wait_for_enqueue: false
      }

      assert BlockQueueEthSync.form_block_or_skip(state, true) == {:do_not_form_block, state}
    end

    test "returns :do_not_form_block when already waiting to enqueue a block (waiting_for_enqueue is true)" do
      state = %{
        parent_height: 9382,
        last_enqueued_block_at_height: 9210,
        minimal_enqueue_block_gap: 1,
        wait_for_enqueue: true
      }

      assert BlockQueueEthSync.form_block_or_skip(state, false) == {:do_not_form_block, state}
    end

    test "returns :do_not_form_block when minimal gap not reached" do
      state = %{
        parent_height: 9382,
        last_enqueued_block_at_height: 9380,
        minimal_enqueue_block_gap: 10,
        wait_for_enqueue: false
      }

      assert BlockQueueEthSync.form_block_or_skip(state, false) == {:do_not_form_block, state}
    end

    test "returns :do_not_form_block when parent height == last enqueue height" do
      state = %{
        parent_height: 9382,
        last_enqueued_block_at_height: 9382,
        minimal_enqueue_block_gap: 1,
        wait_for_enqueue: false
      }

      assert BlockQueueEthSync.form_block_or_skip(state, false) == {:do_not_form_block, state}
    end
  end
end
