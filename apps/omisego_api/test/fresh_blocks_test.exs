defmodule OmiseGO.API.FreshBlocksTest do
  use ExUnit.Case, async: true

  alias OmiseGO.API.FreshBlocks.Core, as: FreshBlocks
  alias OmiseGO.API.Block

  def generate_blocks(range) do
    Enum.map(range, &%Block{hash: &1})
  end

  def generate_fresh_block(size, max_size \\ 1024) do
    update_state = fn block, state ->
      with {:ok, n_state} <- FreshBlocks.push(block, state) do
        n_state
      end
    end

    Enum.reduce(generate_blocks(0..(size - 1)), %FreshBlocks{max_size: max_size}, update_state)
  end

  test "slicing oldest to max size cache" do
    max_size = 10
    state = generate_fresh_block(max_size + 1, max_size)
    {nil, [0]} = FreshBlocks.get(0, state)
    {_, []} = FreshBlocks.get(1, state)
  end

  test "getting Block" do
    range = 20..80
    state = generate_fresh_block(90)
    for hash <- range, do: {%Block{hash: ^hash}, []} = FreshBlocks.get(hash, state)
  end
end
