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

defmodule OMG.API.FreshBlocksTest do
  use ExUnit.Case, async: true

  alias OMG.API.FreshBlocks.Core, as: FreshBlocks
  alias OMG.Block

  def generate_blocks(range) do
    Enum.map(range, &%Block{hash: &1})
  end

  def generate_fresh_block(size, max_size \\ 1024) do
    update_state = fn block, state ->
      assert {:ok, n_state} = FreshBlocks.push(block, state)
      n_state
    end

    Enum.reduce(generate_blocks(0..(size - 1)), %FreshBlocks{max_size: max_size}, update_state)
  end

  test "slicing oldest to max size cache" do
    max_size = 10
    state = generate_fresh_block(max_size + 1, max_size)
    assert {nil, [0]} = FreshBlocks.get(0, state)
    assert {_, []} = FreshBlocks.get(1, state)
  end

  test "getting Block" do
    range = 20..80
    state = generate_fresh_block(90)
    for hash <- range, do: assert({%Block{hash: ^hash}, []} = FreshBlocks.get(hash, state))
  end

  test "can push and pop a lot of blocks from queue" do
    state = generate_fresh_block(200, 3)
    # those that are fresh
    for hash <- 197..199, do: assert({%Block{hash: ^hash}, []} = FreshBlocks.get(hash, state))
    # old ones
    for hash <- 0..196, do: assert({nil, [^hash]} = FreshBlocks.get(hash, state))
  end

  test "empty fresh blocks makes sense" do
    state = %FreshBlocks{}
    hash = "anything"
    assert {nil, [^hash]} = FreshBlocks.get(hash, state)
  end

  test "combines a fresh block with db result" do
    state = generate_fresh_block(10, 9)

    # fresh block
    {fresh_block, _block_hashes_to_fetch} = FreshBlocks.get(9, state)
    assert {:ok, ^fresh_block} = FreshBlocks.combine_getting_results(fresh_block, {:ok, []})

    # db block
    {nil = fresh_block, [0]} = FreshBlocks.get(0, state)
    assert {:ok, %Block{hash: 0}} = FreshBlocks.combine_getting_results(fresh_block, {:ok, [%Block{hash: 0}]})

    # missing block
    {nil = fresh_block, [11]} = FreshBlocks.get(11, state)
    assert {:error, :not_found} = FreshBlocks.combine_getting_results(fresh_block, {:ok, [:not_found]})

    # tolerate spurrious/erroneous/missing db result, if found a fresh block
    {fresh_block, []} = FreshBlocks.get(9, state)
    assert {:ok, ^fresh_block} = FreshBlocks.combine_getting_results(fresh_block, {:ok, [%Block{hash: 0}]})
    assert {:ok, ^fresh_block} = FreshBlocks.combine_getting_results(fresh_block, {:ok, [%Block{hash: 9}]})
    assert {:ok, ^fresh_block} = FreshBlocks.combine_getting_results(fresh_block, {:ok, [:not_found]})
  end
end
