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

  # def new, do: {:ok, %__MODULE__{blocks: Map.new()}}

  # @spec new(keyword) ::
  #         {:ok, Core.t()} | {:error, :contract_ahead_of_db | :mined_blknum_not_found_in_db | :hashes_dont_match}
  def init(config) do
    # _ = BlockQueueLogger.log(:starting_with_initial_state, initial_state)
    _ =
      Logger.info(
        "Starting BlockQueue at " <>
          "parent_height: #{inspect(parent_height)}, parent_start: #{inspect(chain_start_parent_height)}, " <>
          "mined_child_block: #{inspect(mined_child_block_num)}, stored_child_top_block: #{inspect(stored_child_top_num)}"
      )








  end


    case build_initial_state(config) do
      {:ok, initial_state, known_hashes, top_mined_hash} ->
        finalize_state(initial_state, known_hashes, top_mined_hash)
      error ->
        error
    end
  end

  def init, do: {:ok, %BlockQueueState{blocks: Map.new()}}

  defp build_initial_state(config) do
    with {:ok, initial_state} <- load_initial_state(%BlockQueueState{}, config),
         {:ok, known_hashes, top_mined_hash} = compute_mined_and_known_hashes(initial_state) do
      {:ok, initial_state, known_hashes, top_mined_hash}
    end
  end

  defp finalize_state(initial_state, known_hashes, top_mined_hash) do
    case finalize_state(initial_state, known_hashes, top_mined_hash) do
      {:ok, state} ->
        {:ok, state}

      {:error, reason} = error when reason in [:mined_hash_not_found_in_db, :contract_ahead_of_db] ->
        _ =
          BlockQueueLogger.log(
            :init_error, %{
              known_hashes: known_hashes,
              parent_height: initial_state.parent_height,
              mined_num: initial_state.mined_child_block_num,
              stored_child_top_num: initial_state.stored_child_top_num
            }
          )

        error

      error ->
        error
    end
  end

  defp load_initial_state(empty_state, %{
    parent_height: parent_height,
    mined_child_block_num: mined_child_block_num,
    chain_start_parent_height: chain_start_parent_height,
    child_block_interval: child_block_interval,
    stored_child_top_num: stored_child_top_num,
    finality_threshold: finality_threshold
  } = config) do


    initial_state = %{empty_state |
      parent_height: parent_height,
      mined_child_block_num: mined_child_block_num,
      chain_start_parent_height: chain_start_parent_height,
      child_block_interval: child_block_interval,
      stored_child_top_num: stored_child_top_num,
      finality_threshold: finality_threshold
    }



    {:ok, initial_state}
  end

  defp compute_mined_and_known_hashes(initial_state) do
    range = child_block_nums_to_init_with(initial_state)
    {:ok, known_hashes} = DB.block_hashes(range)
    {:ok, {top_mined_hash, _}} = RootChain.get_child_chain(initial_state.mined_child_block_num)
    _ = Logger.info("Starting BlockQueue, top_mined_hash: #{inspect(Encoding.to_hex(top_mined_hash))}")
    # _ = BlockQueueLogger.log(:starting_with_minted_and_known_hashes, {known_hashes, top_mined_hash}),

    {:ok, range, known_hashes, top_mined_hash}
  end

  defp update_initial_state(initial_state, range, known_hashes, top_mined_hash) do
    %{initial_state |
      known_hashes: Enum.zip(range, known_hashes),
      top_mined_hash: top_mined_hash
    }
  end

  @doc """
  Generates an enumberable of block numbers to be starting the BlockQueue with
  (inclusive and it takes `finality_threshold` blocks before the youngest mined block)
  """
  # @spec child_block_nums_to_init_with(non_neg_integer, non_neg_integer, pos_integer, non_neg_integer) :: list
  def child_block_nums_to_init_with(%{
    mined_child_block_num: mined_num,
    stored_child_top_num: until_child_block_num,
    child_block_interval: interval,
    finality_threshold: finality_threshold
  } = initial_state) do
    make_range(max(interval, mined_num - finality_threshold * interval), until_child_block_num, interval)
  end

    # :lists.seq/3 throws, so wrapper
  defp make_range(first, last, _) when first > last, do: []

  defp make_range(first, last, step) do
    :lists.seq(first, last, step)
  end
end
