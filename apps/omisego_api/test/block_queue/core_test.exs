defmodule OmiseGO.API.BlockQueue.CoreTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import OmiseGO.API.BlockQueue.Core
  alias OmiseGO.Eth.BlockSubmission

  def hashes(blocks) do
    for block <- blocks, do: block.hash
  end

  def empty do
    {:ok, state} = new()
    state
  end

  def make_chain(length) do
    {queue, _} =
    1..length
    |> Enum.reduce(set_mined(empty(), 0), fn(hash, state) -> enqueue_block(state, hash) end)
    |> set_ethereum_height(length)

    queue
    |> set_mined(length * 1000)
  end

  def recover(known_hashes, mined_child_block_num) do
    top_mined_hash = "#{inspect trunc(mined_child_block_num / 1000)}"
    new(
      mined_child_block_num: mined_child_block_num,
      known_hashes: known_hashes,
      top_mined_hash: top_mined_hash,
      parent_height: 10,
      child_block_interval: 1000,
      chain_start_parent_height: 1,
      submit_period: 1,
      finality_threshold: 12)
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

    test "Produced child block numbers are as expected" do
      assert {:ok, 1000} =
        empty()
        |> set_mined(0)
        |> enqueue_block("1")
        |> get_formed_block_num(0)
    end

    test "Produced blocks submission requests have nonces in order" do
      assert [_, %{nonce: 2}] =
        empty()
        |> set_mined(0)
        |> enqueue_block("1")
        |> enqueue_block("2")
        |> get_blocks_to_submit()
    end

    test "Block generation is driven by Ethereum height" do
      assert {queue, [_one_to_form]} =
        empty()
        |> set_mined(0)
        |> set_ethereum_height(1)

      queue =
        queue
        |> enqueue_block("1")

      assert {queue, []} =
        queue
        |> set_ethereum_height(0)

      assert {queue, []} =
        queue
        |> set_ethereum_height(1)

      assert {queue, [_one_to_form]} =
        queue
        |> set_ethereum_height(2)

      queue =
        queue
        |> enqueue_block("2")

      assert {_, []} =
        queue
        |> set_ethereum_height(2)
    end

    test "Smoke test" do
      assert {queue, []} =
        empty()
        |> set_mined(0)
        |> enqueue_block("1")
        |> enqueue_block("2")
        |> enqueue_block("3")
        |> enqueue_block("4")
        |> enqueue_block("5")
        |> set_mined(2000)
        |> set_ethereum_height(3)

      assert ["3", "4", "5"] =
        queue
        |> get_blocks_to_submit()
        |> hashes()
    end

    test "Old blocks are GCd" do
      long  = 10000 |> make_chain() |> :erlang.term_to_binary() |> byte_size()
      short = 100 |> make_chain() |> :erlang.term_to_binary() |> byte_size()
      assert 0.9 < long/short and long/short < (1/0.9)
    end

    test "Pending tx can be resubmitted with new gas price" do
      {queue, _} =
        empty()
        |> set_mined(0)
        |> set_gas_price(1)
        |> enqueue_block("1")
        |> enqueue_block("2")
        |> set_ethereum_height(5)

      blocks = get_blocks_to_submit(queue)
      assert %BlockSubmission{gas_price: 1} = hd(blocks)
      blocks2 =
        queue
        |> set_gas_price(555)
        |> get_blocks_to_submit()
      assert %BlockSubmission{gas_price: 555} = hd(blocks2)
      assert length(blocks) == length(blocks2)
    end
  end
end
