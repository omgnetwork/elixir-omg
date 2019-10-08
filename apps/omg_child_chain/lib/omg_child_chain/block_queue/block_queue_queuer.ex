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

defmodule OMG.ChildChain.BlockQueue.BlockQueueQueuer do
  @moduledoc """
  This module is responsible for enqueuing blocks. The main 3 entry points for
  the queueing mechanism are:

    - enqueue_block
    - enqueue_existing_blocks

  See docs for those functions for more details.
  """
  use OMG.Utils.LoggerExt

  alias OMG.ChildChain.BlockQueue.BlockSubmission
  alias OMG.Block

  @zero_bytes32 <<0::size(256)>>

  # The queue_state is a subset of fields from %BlockQueueState{} that
  # are needed to interact with the functions in this module.
  @type queue_state() :: %{
          blocks: list(Block.t()),
          known_hashes: list(String.t()),
          top_mined_hash: String.t(),
          mined_child_block_num: pos_integer(),
          child_block_interval: pos_integer(),
          last_enqueued_block_at_height: pos_integer(),
          wait_for_enqueue: boolean(),
          parent_height: pos_integer(),
          formed_child_block_num: pos_integer()
        }

  @doc ~S"""
  Checks if the received block number is correct, and proceeds to add it to the
  list of blocks in the state if it is. This ensures the blocks we publish
  follow each other using the defined interval.

  ## Examples

      iex> BlockQueueQueuer.enqueue_block(
      ...> %{
      ...>   formed_child_block_num: 1000,
      ...>   child_block_interval: 1000,
      ...>   blocks: %{},
      ...>   wait_for_enqueue: nil,
      ...>   last_enqueued_block_at_height: nil
      ...> },
      ...> %Block{hash: "hash", number: 2000},
      ...> 10
      ...> )
      %{
        formed_child_block_num: 2000,
        wait_for_enqueue: false,
        last_enqueued_block_at_height: 10,
        child_block_interval: 1000,
        blocks: %{
          2000 => %BlockSubmission{hash: "hash", nonce: 2, num: 2000}
        }
      }

  """
  @spec enqueue_block(queue_state(), Block.t(), non_neg_integer) ::
          queue_state() | {:error, :unexpected_block_number}
  def enqueue_block(state, %{hash: hash, number: expected_block_number}, parent_height) do
    own_height = state.formed_child_block_num + state.child_block_interval

    case validate_block_number(expected_block_number, own_height) do
      :ok ->
        do_enqueue_block(state, hash, parent_height)

      error ->
        error
    end
  end

  defp do_enqueue_block(state, hash, parent_height) do
    own_height = state.formed_child_block_num + state.child_block_interval
    nonce = calc_nonce(own_height, state.child_block_interval)
    block = %BlockSubmission{num: own_height, nonce: nonce, hash: hash}
    blocks = Map.put(state.blocks, own_height, block)

    %{
      state
      | formed_child_block_num: own_height,
        blocks: blocks,
        wait_for_enqueue: false,
        last_enqueued_block_at_height: parent_height
    }
  end

  defp validate_block_number(block_number, block_number), do: :ok
  defp validate_block_number(_, _), do: {:error, :unexpected_block_number}

  defp calc_nonce(height, interval) do
    trunc(height / interval)
  end

  @doc ~S"""
  When restarting, we don't actually know what was the state of submission process to Ethereum.
  Some blocks might have been submitted and lost/rejected/reorged by Ethereum in the mean time.
  To properly restart the process we get last blocks known to DB and split them into mined
  blocks (might still need tracking!) and blocks not yet submitted.

  NOTE: handles both the case when there aren't any hashes in database, and when there are.

  ## Examples

      iex> BlockQueueQueuer.enqueue_existing_blocks(
      ...> %{
      ...>   blocks: [],
      ...>   known_hashes: [{1000, "hash_1000"}, {2000, "hash_2000"}],
      ...>   top_mined_hash: "hash_1000",
      ...>   mined_child_block_num: 1000,
      ...>   child_block_interval: 1_000,
      ...>   last_enqueued_block_at_height: 1,
      ...>   wait_for_enqueue: false,
      ...>   parent_height: 10,
      ...>   formed_child_block_num: nil
      ...> })
      {:ok, %{
        formed_child_block_num: 2000,
        wait_for_enqueue: false,
        last_enqueued_block_at_height: 10,
        child_block_interval: 1_000,
        known_hashes: [{1000, "hash_1000"}, {2000, "hash_2000"}],
        mined_child_block_num: 1000,
        parent_height: 10,
        top_mined_hash: "hash_1000",
        blocks: %{
          1000 => %BlockSubmission{hash: "hash_1000", nonce: 1, num: 1000},
          2000 => %BlockSubmission{hash: "hash_2000", nonce: 2, num: 2000}
        }
      }}

  """
  @spec enqueue_existing_blocks(queue_state()) ::
          {:ok, Map.t()} | {:error, :contract_ahead_of_db | :mined_blknum_not_found_in_db | :hashes_dont_match}
  def enqueue_existing_blocks(
        %{
          top_mined_hash: @zero_bytes32,
          known_hashes: []
        } = state
      ) do
    # we start a fresh queue from db and fresh contract
    {:ok, %{state | formed_child_block_num: 0}}
  end

  def enqueue_existing_blocks(
        %{
          known_hashes: []
        } = _state
      ) do
    # something's wrong - no hashes in db and top_mined hash isn't a zero hash as required
    {:error, :contract_ahead_of_db}
  end

  def enqueue_existing_blocks(
        %{
          top_mined_hash: top_mined_hash,
          known_hashes: known_hashes
        } = state
      ) do
    with :ok <- block_number_and_hash_valid?(top_mined_hash, state.mined_child_block_num, known_hashes) do
      {mined_blocks, fresh_blocks} = split_existing_blocks(state, known_hashes)

      mined_submissions =
        for {num, hash} <- mined_blocks do
          {num,
           %BlockSubmission{
             num: num,
             hash: hash,
             nonce: calc_nonce(num, state.child_block_interval)
           }}
        end
        |> Map.new()

      state = %{
        state
        | formed_child_block_num: state.mined_child_block_num,
          blocks: mined_submissions
      }

      _ = Logger.info("Loaded with #{inspect(mined_blocks)} mined and #{inspect(fresh_blocks)} enqueued")

      {:ok, Enum.reduce(fresh_blocks, state, fn hash, acc -> do_enqueue_block(acc, hash, state.parent_height) end)}
    end
  end

  # splits into ones that are before top_mined_hash and those after
  # mined are zipped with their numbers to submit
  defp split_existing_blocks(%{mined_child_block_num: blknum}, blknums_and_hashes) do
    {mined, fresh} =
      Enum.find_index(blknums_and_hashes, &(elem(&1, 0) == blknum))
      |> case do
        nil -> {[], blknums_and_hashes}
        index -> Enum.split(blknums_and_hashes, index + 1)
      end

    fresh_hashes = Enum.map(fresh, &elem(&1, 1))

    {mined, fresh_hashes}
  end

  defp block_number_and_hash_valid?(@zero_bytes32, 0, _) do
    :ok
  end

  defp block_number_and_hash_valid?(expected_hash, blknum, blknums_and_hashes) do
    validate_block_hash(
      expected_hash,
      Enum.find(blknums_and_hashes, fn {num, _hash} -> blknum == num end)
    )
  end

  defp validate_block_hash(expected, {_blknum, blkhash}) when expected == blkhash, do: :ok
  defp validate_block_hash(_, nil), do: {:error, :mined_blknum_not_found_in_db}
  defp validate_block_hash(_, _), do: {:error, :hashes_dont_match}
end
