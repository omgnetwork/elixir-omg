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

defmodule OMG.ChildChain.BlockQueue.BlockQueueSubmitter do
  @moduledoc """
  This module handles everything related to the submission of blocks
  from the block queue.

    - pending_mining_filter_func: build a function to filter the blocks to submit
    - get_blocks_to_submit: returns a list of blocks that need to be submitted
    - submit: actually submit a block to the rootchain
    - process_submit_result: handles the rootchain response

  See docs for those functions for more details.
  """
  alias OMG.ChildChain.BlockQueue.BlockSubmission
  alias OMG.ChildChain.BlockQueue.BlockQueueLogger

  alias OMG.Eth.RootChain

  alias OMG.Block

  @type pending_mining_filter_type() :: %{
          formed_child_block_num: pos_integer(),
          mined_child_block_num: pos_integer(),
          child_block_interval: pos_integer()
        }
  # Subset of the BlockQueueState struct needed to interact
  # with the get_blocks_to_submit() function.
  @type blocks_to_submit_type() :: %{
          blocks: list(Block.t()),
          child_block_interval: pos_integer(),
          gas_price_to_use: pos_integer(),
          mined_child_block_num: pos_integer(),
          formed_child_block_num: pos_integer()
        }
  @type submit_result_t() :: {:ok, <<_::256>>} | {:error, map}

  @doc ~S"""
  Builds and return an anonymous function that can be used to
  filter a list of block numbers between the mined_child_block_num + interval
  (inclusive) and the formed_child_block_num (inclusive).

  ## Examples

      iex> Enum.filter([{1, nil}, {2, nil}, {3, nil}],
      ...>   BlockQueueSubmitter.pending_mining_filter_func(%{
      ...>     formed_child_block_num: 3,
      ...>     mined_child_block_num: 1,
      ...>     child_block_interval: 1
      ...>   })
      ...> )
      [{2, nil}, {3, nil}]

  """
  @spec pending_mining_filter_func(pending_mining_filter_type()) :: Func.t()
  def pending_mining_filter_func(%{
        formed_child_block_num: formed_child_block_num,
        mined_child_block_num: mined_child_block_num,
        child_block_interval: child_block_interval
      }) do
    fn {blknum, _} ->
      # We only keep blocks that are higher or equal than the last mined child block
      # and lower or equal to the last formed child block
      first_block_to_mine_num(mined_child_block_num, child_block_interval) <= blknum and
        blknum <= formed_child_block_num
    end
  end

  @doc ~S"""
  Compute which blocks need to be submitted based on
  the blocks already mined on the rootchain and the blocks
  formed in the childchain. All blocks that have been formed
  after the last block the rootchain has seen should be submitted.

  ## Examples

    In this example, the blocks are simple maps, while in the
    actual code, they would be %BlockSubmission{} structs.

      iex> BlockQueueSubmitter.get_blocks_to_submit(%{
      ...>   blocks: %{1000 => %{num: 1000}, 2000 => %{num: 2000}},
      ...>   formed_child_block_num: 2000,
      ...>   gas_price_to_use: 1,
      ...>   mined_child_block_num: 1000,
      ...>   child_block_interval: 1000
      ...> })
      [%{gas_price: 1, num: 2000}]

  """
  @spec get_blocks_to_submit(blocks_to_submit_type()) :: [%BlockSubmission{}]
  def get_blocks_to_submit(
        %{
          blocks: blocks,
          child_block_interval: child_block_interval,
          gas_price_to_use: gas_price_to_use,
          mined_child_block_num: mined_child_block_num,
          formed_child_block_num: formed_child_block_num
        } = state
      ) do
    first_block_to_mine_num = first_block_to_mine_num(mined_child_block_num, child_block_interval)

    _ =
      BlockQueueLogger.log(:preparing_blocks, %{
        first_block_to_mine_num: first_block_to_mine_num,
        formed_child_block_num: formed_child_block_num
      })

    blocks
    |> Enum.filter(pending_mining_filter_func(state))
    |> Enum.map(fn {_blknum, block} -> block end)
    |> Enum.sort_by(& &1.num)
    |> Enum.map(&Map.put(&1, :gas_price, gas_price_to_use))
  end

  @doc ~S"""
  Submits a block to the rootchain. The actual rootchain module to use
  can be passed if needed.

  ## Examples

      iex> BlockQueueSubmitter.submit(
      ...>   %BlockSubmission{hash: "success", nonce: 1, gas_price: 1},
      ...>   OMG.ChildChain.FakeRootChain
      ...> )
      :ok

  """
  @spec submit(%BlockSubmission{}) :: :ok
  def submit(%BlockSubmission{hash: hash, nonce: nonce, gas_price: gas_price} = submission, chain \\ RootChain) do
    _ = BlockQueueLogger.log(:submitting_block, submission)
    {:ok, newest_mined_blknum} = chain.get_mined_child_block()

    hash
    |> chain.submit_block(nonce, gas_price)
    |> process_submit_result(submission, newest_mined_blknum)
    |> return_result_and_log()
  end

  @doc ~S"""
  Submits a block to the rootchain. The actual rootchain module to use
  can be passed if needed.

  ## Examples

      iex> BlockQueueSubmitter.process_submit_result(
      ...>   {:ok, "hash"},
      ...>   %BlockSubmission{},
      ...>   1
      ...> )
      :ok

  """
  @spec process_submit_result(submit_result_t(), BlockSubmission.t(), BlockSubmission.plasma_block_num()) ::
          :ok | {:error, atom}
  def process_submit_result(submit_result, submission, newest_mined_blknum) do
    case submit_result do
      {:ok, txhash} ->
        BlockQueueLogger.log(:submitted_block, %{submission: submission, txhash: txhash})
        :ok

      {:error, %{"code" => -32_000, "message" => "known transaction" <> _}} ->
        BlockQueueLogger.log(:known_tx, submission)
        :ok

      # parity error code for duplicated tx
      {:error, %{"code" => -32_010, "message" => "Transaction with the same hash was already imported."}} ->
        BlockQueueLogger.log(:known_tx, submission)
        :ok

      {:error, %{"code" => -32_000, "message" => "replacement transaction underpriced"}} ->
        BlockQueueLogger.log(:low_replacement_price, submission)
        :ok

      # parity version
      {:error, %{"code" => -32_010, "message" => "Transaction gas price is too low. There is another" <> _}} ->
        BlockQueueLogger.log(:low_replacement_price, submission)
        :ok

      {:error, %{"code" => -32_000, "message" => "authentication needed: password or unlock"}} ->
        BlockQueueLogger.log(:authority_locked, %{submission: submission, newest_mined_blknum: newest_mined_blknum})
        {:error, :account_locked}

      {:error, %{"code" => -32_000, "message" => "nonce too low"}} ->
        process_nonce_too_low(submission, newest_mined_blknum)

      # parity specific error for nonce-too-low
      {:error, %{"code" => -32_010, "message" => "Transaction nonce is too low." <> _}} ->
        process_nonce_too_low(submission, newest_mined_blknum)
    end
  end

  defp return_result_and_log({:error, _}) do
    BlockQueueLogger.log(:eth_node_error)
    # TODO: Change this
    raise "NotSureWhatToDoError"
  end

  defp return_result_and_log(:ok), do: :ok

  defp process_nonce_too_low(%BlockSubmission{num: blknum} = submission, newest_mined_blknum) do
    case blknum <= newest_mined_blknum do
      true ->
        # apparently the `nonce too low` error is related to the submission having been mined while it was prepared
        :ok

      false ->
        BlockQueueLogger.log(:nonce_too_low, %{submission: submission, newest_mined_blknum: newest_mined_blknum})
        {:error, :nonce_too_low}
    end
  end

  defp first_block_to_mine_num(mined_child_block_num, child_block_interval) do
    mined_child_block_num + child_block_interval
  end
end
