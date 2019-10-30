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

defmodule OMG.ChildChain.BlockQueue.BlockQueueInitializer do
  @moduledoc """

  """
  require Logger

  alias OMG.ChildChain.BlockQueue.BlockQueueState

  alias OMG.Eth.Encoding

  @type init_config_t() :: %{
          parent_height: pos_integer(),
          mined_child_block_num: pos_integer(),
          chain_start_parent_height: pos_integer(),
          child_block_interval: pos_integer(),
          finality_threshold: pos_integer(),
          minimal_enqueue_block_gap: pos_integer(),
          known_hashes: list(String.t()),
          top_mined_hash: String.t(),
          last_enqueued_block_at_height: pos_integer()
        }

  # def new, do: {:ok, %__MODULE__{blocks: Map.new()}}

  # @spec new(keyword) ::
  #         {:ok, Core.t()} | {:error, :contract_ahead_of_db | :mined_blknum_not_found_in_db | :hashes_dont_match}
  def init(
        %{
          parent_height: parent_height,
          mined_child_block_num: mined_child_block_num,
          chain_start_parent_height: chain_start_parent_height,
          child_block_interval: child_block_interval,
          finality_threshold: finality_threshold,
          minimal_enqueue_block_gap: minimal_enqueue_block_gap,
          known_hashes: known_hashes,
          top_mined_hash: top_mined_hash,
          last_enqueued_block_at_height: last_enqueued_block_at_height
        } = config
      ) do
    # _ = BlockQueueLogger.log(:starting_with_initial_state, initial_state)
    # TODO: Move to server config?
    stored_child_top_num = config[:stored_child_top_num]

    _ =
      Logger.info(
        "Starting BlockQueue at " <>
          "parent_height: #{inspect(parent_height)}, parent_start: #{inspect(chain_start_parent_height)}, " <>
          "mined_child_block: #{inspect(mined_child_block_num)}, stored_child_top_block: #{
            inspect(stored_child_top_num)
          }"
      )

    # TODO: Move to server config?
    _ = Logger.info("Starting BlockQueue, top_mined_hash: #{inspect(Encoding.to_hex(top_mined_hash))}")

    %BlockQueueState{
      blocks: Map.new(),
      mined_child_block_num: mined_child_block_num,
      known_hashes: known_hashes,
      top_mined_hash: top_mined_hash,
      parent_height: parent_height,
      child_block_interval: child_block_interval,
      chain_start_parent_height: chain_start_parent_height,
      minimal_enqueue_block_gap: minimal_enqueue_block_gap,
      finality_threshold: finality_threshold,
      last_enqueued_block_at_height: last_enqueued_block_at_height
    }
  end

  def init, do: {:ok, %BlockQueueState{blocks: Map.new()}}

  # _ =
  # BlockQueueLogger.log(
  #   :init_error, %{
  #     known_hashes: known_hashes,
  #     parent_height: initial_state.parent_height,
  #     mined_num: initial_state.mined_child_block_num,
  #     stored_child_top_num: initial_state.stored_child_top_num
  #   }
  # )

  @doc """
  Generates an enumberable of block numbers to be starting the BlockQueue with
  (inclusive and it takes `finality_threshold` blocks before the youngest mined block)
  """
  # @spec child_block_nums_to_init_with(non_neg_integer, non_neg_integer, pos_integer, non_neg_integer) :: list
  def child_block_nums_to_init_with(mined_child_block_num, until_child_block_num, interval, finality_threshold) do
    make_range(max(interval, mined_child_block_num - finality_threshold * interval), until_child_block_num, interval)
  end

  # :lists.seq/3 throws, so wrapper
  defp make_range(first, last, _) when first > last, do: []

  defp make_range(first, last, step) do
    :lists.seq(first, last, step)
  end
end
