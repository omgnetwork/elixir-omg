defmodule OmiseGO.API.BlockQueueTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import OmiseGO.API.BlockQueue.Core

  def hashes({:ok, blocks}) do
    for block <- blocks, do: block.hash
  end

  def flip(flipped_fun) when is_function(flipped_fun, 2) do
    fn(x, y) -> flipped_fun.(y, x) end
  end

  def make_chain(length) do
    1..length
    |> Enum.reduce(set_mined(new(), 0), flip(&enqueue_block/2))
    |> set_parent_height(length)
    |> set_mined(length * 1000)
  end

  describe "Block queue." do
    test "No submitBlock will be sent until properly initialized" do
      assert {:error, :uninitialized} =
        new()
        |> set_mined(0)
        |> enqueue_block(1)
        |> get_blocks_to_submit()
    end

    test "Smoke test" do
      assert ["3"] =
        new()
        |> set_mined(0)
        |> enqueue_block("1")
        |> enqueue_block("2")
        |> enqueue_block("3")
        |> enqueue_block("4")
        |> enqueue_block("5")
        |> set_mined(2000)
        |> set_parent_height(3)
        |> get_blocks_to_submit()
        |> hashes()
    end

    test "Old blocks are GCd" do
      long  = 10000 |> make_chain() |> :erlang.term_to_binary() |> byte_size()
      short = 100 |> make_chain() |> :erlang.term_to_binary() |> byte_size()
      assert 0.9 < long/short and long/short < (1/0.9)
    end
  end
end
