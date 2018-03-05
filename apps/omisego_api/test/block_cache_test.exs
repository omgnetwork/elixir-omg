defmodule OmiseGO.BlockCacheTest do
  use ExUnit.Case, async: true
  doctest OmiseGO.BlockCache

  alias OmisseGo.BlockCache, as: BlockCache


  def generate_blocks(range) do
    Enum.map(range, &(%Block{number:&1}))
  end

  def generate_blockCache(size, max_size//:math.pow(2,10)) do
    Enum.reduce(
       generate_blocks(0..size-1)
      %BlockCache{max_size:max_size},
      &BlockCache.update(&1,&2)
    )
  end

  test "slisink oldest to max size cache" do
    max_size = 10
    state = geneerate_blockCache(max_size+1,max_size)
    assert BlockCache.contain?(0, state) == false
    assert BlockCache.contain?(1, state) == true
  end

  test "getting Block" do
      range = 20..80
      blocks = generate_block(range)
      block_cache = generate_blockCache(90)
      for number <- range, do: assert BlockCache.get(number,state)
  end
end
