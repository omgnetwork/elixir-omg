defmodule OmiseGO.API.BlockQueueTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import OmiseGO.API.BlockQueue.Core
  import OmiseGO.API.BlockQueue.Core.BlockSubmission

  def hashes(blocks) do
    for block <- blocks, do: block.hash
  end

  def empty do
    {:ok, state} = new()
    state
  end

  def make_chain(length) do
    1..length
    |> Enum.reduce(set_mined(empty(), 0), fn(hash, state) -> enqueue_block(state, hash) end)
    |> set_ethereum_height(length)
    |> set_mined(length * 1000)
  end

  def recover(known_hashes, mined_num) do
    top_mined_hash = "#{inspect trunc(mined_num / 1000)}"
    new(
      child_block_interval: 1000,
      chain_start_parent_height: 1,
      submit_period: 1,
      finality_threshold: 12,
      known_hashes: known_hashes,
      top_mined_hash: top_mined_hash,
      mined_num: mined_num,
      parent_height: 10)
  end

  describe "Block queue." do
    test "Recovers after restart to proper mined height" do
      assert ["8", "9"] =
        ["5", "6", "7", "8", "9"]
        |> recover(7000)
        |> elem(1)
        |> get_blocks_to_submit()
        |> hashes()
    end

    test "Recovers after restart and is able to process more blocks" do
      assert ["8", "9", "10"] =
        ["5", "6", "7", "8", "9"]
        |> recover(7000)
        |> elem(1)
        |> enqueue_block("10")
        |> get_blocks_to_submit()
        |> hashes()
    end

    @tag :current
    test "Recovery will fail if DB is corrupted" do
      assert false == recover(["5", "6"], 7000)
    end

    test "No submitBlock will be sent until properly initialized" do
      catch_error get_blocks_to_submit(new())
    end

    test "All new block are emitted ASAP" do
      assert ["1"] =
        empty()
        |> set_mined(0)
        |> enqueue_block("1")
        |> get_blocks_to_submit()
        |> hashes()
    end

    test "Block generation is driven by Ethereum height" do
      queue =
        empty()
        |> set_mined(0)
        |> set_ethereum_height(1)
      assert create_block?(queue)
      queue =
        queue
        |> enqueue_block("1")
      assert not create_block?(queue)
      queue =
        queue
        |> set_ethereum_height(0)
      assert not create_block?(queue)
      queue =
        queue
        |> set_ethereum_height(1)
      assert not create_block?(queue)
      queue =
        queue
        |> set_ethereum_height(2)
      assert create_block?(queue)
      queue =
        queue
        |> enqueue_block("2")
      assert not create_block?(queue)
    end

    test "Smoke test" do
      assert ["3", "4", "5"] =
        empty()
        |> set_mined(0)
        |> enqueue_block("1")
        |> enqueue_block("2")
        |> enqueue_block("3")
        |> enqueue_block("4")
        |> enqueue_block("5")
        |> set_mined(2000)
        |> set_ethereum_height(3)
        |> get_blocks_to_submit()
        |> hashes()
    end

    test "Old blocks are GCd" do
      long  = 10000 |> make_chain() |> :erlang.term_to_binary() |> byte_size()
      short = 100 |> make_chain() |> :erlang.term_to_binary() |> byte_size()
      assert 0.9 < long/short and long/short < (1/0.9)
    end

    test "Pending tx can be resubmitted with new gas price" do
      queue =
        empty()
        |> set_mined(0)
        |> set_gas_price(1)
        |> enqueue_block("1")
        |> enqueue_block("2")
        |> set_ethereum_height(5)
      blocks = get_blocks_to_submit(queue)
      assert 1 = hd(blocks).gas
      blocks2 =
        queue
        |> set_gas_price(555)
        |> get_blocks_to_submit()
      assert 555 = hd(blocks2).gas
      assert length(blocks) == length(blocks2)
    end
  end
end
