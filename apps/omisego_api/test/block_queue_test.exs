defmodule OmiseGO.BlockQueueTest do
  @moduledoc """
  """

  use ExUnit.Case, async: true

  import OmiseGo.BlockQueue.Core

  describe "block queue" do
    test "uninitialized returns empty list" do
      assert [] =
        new()
        |> enqueue_block(1)
        |> get_blocks_to_submit(100000)
    end

    test "get me some blocks" do
      assert [] =
        new()
        |> enqueue_block(1)
        |> enqueue_block(2)
        |> enqueue_block(3)
        |> enqueue_block(4)
        |> get_blocks_to_submit(100000)
    end
  end
end
