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

defmodule OMG.ChildChain.BlockQueue.BlockQueueQueuerTest do
  @moduledoc false
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.ChildChain.BlockQueue.BlockSubmission
  alias OMG.ChildChain.BlockQueue.BlockQueueQueuer

  alias OMG.Block

  @child_block_interval 1000

  doctest OMG.ChildChain.BlockQueue.BlockQueueQueuer

  describe "enqueue_block/3" do
    test "enqueue a new block following a regular block" do
      state = %{
        formed_child_block_num: 10_000,
        child_block_interval: @child_block_interval,
        blocks: %{},
        wait_for_enqueue: nil,
        last_enqueued_block_at_height: nil
      }

      block = %Block{hash: "hash", number: 11_000}
      parent_height = 10

      assert BlockQueueQueuer.enqueue_block(state, block, parent_height) == %{
               formed_child_block_num: 11_000,
               wait_for_enqueue: false,
               last_enqueued_block_at_height: 10,
               child_block_interval: @child_block_interval,
               blocks: %{
                 11_000 => %BlockSubmission{hash: "hash", nonce: 11, num: 11_000}
               }
             }
    end

    test "fails to enqueue a new block when the expected_block_number is different from the current height" do
      # In this case, the gap between the blocks is 3000, while the interval is set to 1000.
      # The validation will fails and return an error because the expected value is 9000.
      state = %{
        formed_child_block_num: 8_000,
        child_block_interval: @child_block_interval,
        blocks: %{},
        wait_for_enqueue: nil,
        last_enqueued_block_at_height: nil
      }

      block = %Block{hash: "hash", number: 11_000}
      parent_height = 10

      assert BlockQueueQueuer.enqueue_block(state, block, parent_height) == {:error, :unexpected_block_number}
    end
  end

  describe "enqueue_existing_blocks/1" do
    test "skips queueing when there are no existing blocks to queue" do
      state = %{
        top_mined_hash: <<0::size(256)>>,
        known_hashes: [],
        formed_child_block_num: nil
      }

      assert BlockQueueQueuer.enqueue_existing_blocks(state) ==
               {:ok,
                %{
                  top_mined_hash: <<0::size(256)>>,
                  known_hashes: [],
                  formed_child_block_num: 0
                }}
    end

    test "returns the 'contract_ahead_of_db' error when there are no hashes in the DB, but the top mined hash isn't a zero hash" do
      state = %{
        top_mined_hash: "hash",
        known_hashes: []
      }

      assert BlockQueueQueuer.enqueue_existing_blocks(state) == {:error, :contract_ahead_of_db}
    end

    test "returns the 'mined_blknum_not_found_in_db' error when the hash was not found" do
      state = %{
        blocks: [],
        known_hashes: [{1000, "hash_1000"}],
        top_mined_hash: "hash_2000",
        mined_child_block_num: 2000,
        child_block_interval: @child_block_interval,
        formed_child_block_num: nil
      }

      assert BlockQueueQueuer.enqueue_existing_blocks(state) == {:error, :mined_blknum_not_found_in_db}
    end

    test "returns the 'hashes_dont_match' error when hashes for the same block number don't match" do
      state = %{
        blocks: [],
        known_hashes: [{1000, "hash_1000"}],
        top_mined_hash: "bad_hash_1000",
        mined_child_block_num: 1000,
        child_block_interval: @child_block_interval,
        formed_child_block_num: nil
      }

      assert BlockQueueQueuer.enqueue_existing_blocks(state) == {:error, :hashes_dont_match}
    end

    test "enqueues a list of existing mined/fresh blocks successfully" do
      known_hashes = [{1000, "hash_1000"}, {2000, "hash_2000"}, {3000, "hash_3000"}, {4000, "hash_4000"}]

      state = %{
        blocks: [],
        known_hashes: known_hashes,
        top_mined_hash: "hash_2000",
        mined_child_block_num: 2000,
        child_block_interval: @child_block_interval,
        last_enqueued_block_at_height: 1,
        wait_for_enqueue: false,
        parent_height: 10,
        formed_child_block_num: nil
      }

      assert BlockQueueQueuer.enqueue_existing_blocks(state) ==
               {:ok,
                %{
                  blocks: %{
                    1000 => %BlockSubmission{
                      gas_price: nil,
                      hash: "hash_1000",
                      nonce: 1,
                      num: 1000
                    },
                    2000 => %BlockSubmission{
                      gas_price: nil,
                      hash: "hash_2000",
                      nonce: 2,
                      num: 2000
                    },
                    3000 => %BlockSubmission{
                      gas_price: nil,
                      hash: "hash_3000",
                      nonce: 3,
                      num: 3000
                    },
                    4000 => %BlockSubmission{
                      gas_price: nil,
                      hash: "hash_4000",
                      nonce: 4,
                      num: 4000
                    }
                  },
                  child_block_interval: 1000,
                  formed_child_block_num: 4000,
                  known_hashes: known_hashes,
                  last_enqueued_block_at_height: 10,
                  mined_child_block_num: 2000,
                  parent_height: 10,
                  top_mined_hash: "hash_2000",
                  wait_for_enqueue: false
                }}
    end
  end
end
