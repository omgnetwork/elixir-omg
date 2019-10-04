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

  """

  alias OMG.ChildChain.BlockQueue
  alias OMG.ChildChain.BlockQueue.BlockQueueState

  use OMG.Utils.LoggerExt

  @type submit_result_t() :: {:ok, <<_::256>>} | {:error, map}

  # Set number of plasma block mined on the parent chain.

  # Since reorgs are possible, consecutive values of mined_child_block_num don't have to be
  # monotonically increasing. Due to construction of contract we know it does not
  # contain holes so we care only about the highest number.
  @spec set_mined_block_num(BlockQueueState.t(), BlockQueue.plasma_block_num()) :: BlockQueueState.t()
  def set_mined_block_num(state, mined_child_block_num) do
    num_threshold = mined_child_block_num - state.child_block_interval * state.finality_threshold
    young? = fn {_, block} -> block.num > num_threshold end
    blocks = state.blocks |> Enum.filter(young?) |> Map.new()
    top_known_block = max(mined_child_block_num, state.formed_child_block_num)

    %{state | formed_child_block_num: top_known_block, mined_child_block_num: mined_child_block_num, blocks: blocks}
  end

  def form_block_or_skip(state, is_empty_block) do
    case should_form_block?(state, is_empty_block) do
      true ->
        :ok = OMG.State.form_block()
        {:do_form_block, %{state | wait_for_enqueue: true}}

      false ->
        {:do_not_form_block, state}
    end
  end

  @spec should_form_block?(BlockQueueState.t(), boolean()) :: boolean()
  defp should_form_block?(
         %BlockQueueState{
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
