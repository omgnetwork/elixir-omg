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

defmodule OMG.ChildChain.BlockTestHelper do
  alias OMG.ChildChain.BlockQueue.BlockSubmission
  alias OMG.ChildChain.BlockQueue.BlockQueueCore

  @child_block_interval 1_000

  def new_block(number) do
    {number,
     %BlockSubmission{
       gas_price: nil,
       hash: "hash_#{number}",
       nonce: 1,
       num: number
     }}
  end

  def get_blocks(end_count, start_count \\ 1, block_interval \\ @child_block_interval) do
    Enum.into(start_count..end_count, %{}, fn i ->
      new_block(i * block_interval)
    end)
  end

  def get_blocks_list(end_count, start_count \\ 1, block_interval \\ @child_block_interval, gas \\ 1) do
    end_count
    |> get_blocks(start_count, block_interval)
    |> Enum.map(fn {_blknum, block} ->
      %{block | gas_price: gas}
    end)
  end

  defp get_submission(hash \\ "hash_1000", num \\ 10) do
    %BlockSubmission{
      hash: hash,
      nonce: 1,
      gas_price: 1,
      num: num
    }
  end

  @doc """
  Create the block_queue new state with non-initial parameters like it was recovered from db after restart / crash
  If top_mined_hash parameter is ommited it will be generated from mined_child_block_num
  """
  def recover_state(known_hashes, mined_child_block_num, top_mined_hash \\ nil) do
    top_mined_hash = top_mined_hash || "#{Kernel.inspect(trunc(mined_child_block_num / 1000))}"

    BlockQueueCore.init(%{
      parent_height: 10,
      mined_child_block_num: mined_child_block_num,
      chain_start_parent_height: 1,
      child_block_interval: @child_block_interval,
      finality_threshold: 12,
      minimal_enqueue_block_gap: 1,
      known_hashes: known_hashes,
      top_mined_hash: top_mined_hash,
      last_enqueued_block_at_height: 0
    })
  end

  # helper function makes a chain that have size blocks
  def make_chain(base, size) do
    if size > 0,
      do:
        1..size
        |> Enum.reduce(base, fn hash, state ->
          BlockQueueCore.enqueue_block(state, %{hash: hash, number: hash * @child_block_interval}, hash)
        end),
      else: base
  end

  def size(state) do
    state |> :erlang.term_to_binary() |> byte_size()
  end
end
