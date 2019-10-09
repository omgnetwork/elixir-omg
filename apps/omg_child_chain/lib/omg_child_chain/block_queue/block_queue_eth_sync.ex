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

defmodule OMG.ChildChain.BlockQueue.BlockQueueEthSync do
  @moduledoc """
  This module receives details about the current state of the queue and
  compute the needed actions.

    - set_mined_block_num
    - form_block_or_skip

  See docs for those functions for more details.
  """
  use OMG.Utils.LoggerExt

  alias OMG.ChildChain.BlockQueue.BlockQueueState

  # The sync_state is a subset of fields from %BlockQueueState{} that
  # are needed to interact with the functions in this module.
  @type sync_state() :: %{
          blocks: list(Block.t()),
          child_block_interval: pos_integer(),
          finality_threshold: pos_integer(),
          formed_child_block_num: pos_integer(),
          mined_child_block_num: pos_integer()
        }

  @type form_block_state() :: %{
          parent_height: pos_integer(),
          last_enqueued_block_at_height: pos_integer(),
          minimal_enqueue_block_gap: pos_integer(),
          wait_for_enqueue: boolean()
        }

  @doc ~S"""
  Updates the mined_child_block_num (block number of the latest child block
  mined on the parent chain) in the state and removes all blocks that have
  reached finality.

  NOTE: Since reorgs are possible, consecutive values of mined_child_block_num don't have to be
  monotonically increasing. Due to construction of contract we know it does not
  contain holes so we care only about the highest number.

  ## Examples

      iex> BlockQueueEthSync.set_mined_block_num(
      ...> %{
      ...>   blocks: %{
      ...>     1000 => %{hash: "hash_1000", nonce: 1, num: 1000},
      ...>     2000 => %{hash: "hash_2000", nonce: 2, num: 2000},
      ...>     3000 => %{hash: "hash_3000", nonce: 3, num: 3000}
      ...>   },
      ...>   child_block_interval: 1000,
      ...>   finality_threshold: 2,
      ...>   formed_child_block_num: 3000,
      ...>   mined_child_block_num: nil
      ...> }, 3000)
      %{
        blocks: %{
          2000 => %{hash: "hash_2000", nonce: 2, num: 2000},
          3000 => %{hash: "hash_3000", nonce: 3, num: 3000}
        },
        child_block_interval: @child_block_interval,
        finality_threshold: 2,
        formed_child_block_num: 3000,
        mined_child_block_num: 3000
      }

  """
  @spec set_mined_block_num(sync_state(), BlockQueueState.plasma_block_num()) :: sync_state()
  def set_mined_block_num(
        %{
          blocks: blocks,
          child_block_interval: child_block_interval,
          finality_threshold: finality_threshold,
          formed_child_block_num: formed_child_block_num
        } = state,
        mined_child_block_num
      ) do
    # Here we take the last block mined on the parent chain and subtract the block interval
    # (normally 1000) by the finality threshold. This is used to removed blocks we don't
    # care about anymore in the following step since we've already reached "finality" for them
    oldest_blknum_to_keep = mined_child_block_num - child_block_interval * finality_threshold

    # We prepare a lambda to check if a block is more recent than
    # the oldest block number we want to track
    should_track? = fn {_, block} ->
      block.num > oldest_blknum_to_keep
    end

    # Then we use that lambda to remove all blocks that are older than the
    # oldest block we want to track since we consider them to have reached
    # finality
    non_final_blocks = blocks |> Enum.filter(should_track?) |> Map.new()

    top_known_block = max(mined_child_block_num, formed_child_block_num)

    %{
      state
      | formed_child_block_num: top_known_block,
        mined_child_block_num: mined_child_block_num,
        blocks: non_final_blocks
    }
  end

  @doc ~S"""
  Checks if a new block should be formed or not. The atoms :do_form_block or
  :do_not_form_block are returned with an updated state depending on the following
  parameters:

    - The parent height must be higher than the last enqueued block height plus the
      configured block gap to respect
    - The queue is not already queuing a new block (wait_for_enqueue is true)
    - The block is not empty

  If this function is called and results with a :do_not_form_block, a debugging
  message will be logged.

  ## Examples

      iex> BlockQueueEthSync.form_block_or_skip(
      ...> %{
      ...>   parent_height: 5,
      ...>   last_enqueued_block_at_height: 1,
      ...>   minimal_enqueue_block_gap: 1,
      ...>   wait_for_enqueue: nil
      ...> }, false)
      {
        :do_form_block,
        %{
          parent_height: 5,
          last_enqueued_block_at_height: 1,
          minimal_enqueue_block_gap: 1,
          wait_for_enqueue: true
        }
      }
  """
  @spec form_block_or_skip(form_block_state(), boolean()) ::
          {:do_form_block, form_block_state()} | {:do_not_form_block, form_block_state()}
  def form_block_or_skip(state, is_empty_block) do
    case should_form_block?(state, is_empty_block) do
      true ->
        {:do_form_block, %{state | wait_for_enqueue: true}}

      false ->
        {:do_not_form_block, state}
    end
  end

  defp should_form_block?(
         %{
           parent_height: parent_height,
           last_enqueued_block_at_height: last_enqueued_block_at_height,
           minimal_enqueue_block_gap: minimal_enqueue_block_gap,
           wait_for_enqueue: wait_for_enqueue
         },
         is_empty_block
       ) do
    is_it_time? = parent_height - last_enqueued_block_at_height > minimal_enqueue_block_gap
    should_form_block? = is_it_time? and !wait_for_enqueue and !is_empty_block

    _ =
      if !should_form_block? do
        log_data = %{
          parent_height: parent_height,
          last_enqueued_block_at_height: last_enqueued_block_at_height,
          minimal_enqueue_block_gap: minimal_enqueue_block_gap,
          wait_for_enqueue: wait_for_enqueue,
          it_is_time: is_it_time?,
          is_empty_block: is_empty_block
        }

        Logger.debug("Skipping forming block because: #{inspect(log_data)}")
      end

    should_form_block?
  end
end
