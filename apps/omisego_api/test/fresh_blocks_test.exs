defmodule OmiseGO.FreshBlocksTest do
  use ExUnit.Case, async: true
  doctest OmiseGO.FreshBlocks

  alias OmiseGO.FreshBlocks.Core, as: FreshBlocks
  alias OmiseGO.FreshBlocks.Block, as: Block

  def generate_blocks(range) do
    Enum.map(range, &%Block{number: &1})
  end

  def generate_fresh_block(size, max_size \\ 1024) do
    update_state = fn state, block ->
      with {:ok, n_state} <- FreshBlocks.update(state, block) do
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
    for number <- range, do: {%Block{number: ^number}, []} = FreshBlocks.get(number, state)
  end
end
