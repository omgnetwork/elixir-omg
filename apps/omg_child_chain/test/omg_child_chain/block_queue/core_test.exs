# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.BlockQueue.CoreTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias OMG.ChildChain.BlockQueue.Core

  @child_block_interval 1000

  # responses from geth to simulate what we're getting from geth in `BlockQueue`
  @known_transaction_response {:error, %{"code" => -32_000, "message" => "known transaction tx"}}
  @replacement_transaction_response {:error, %{"code" => -32_000, "message" => "replacement transaction underpriced"}}
  @nonce_too_low_response {:error, %{"code" => -32_000, "message" => "nonce too low"}}
  @account_locked_response {:error, %{"code" => -32_000, "message" => "authentication needed: password or unlock"}}

  setup do
    {:ok, empty} =
      Core.new(
        mined_child_block_num: 0,
        known_hashes: [],
        top_mined_hash: <<0::256>>,
        parent_height: 0,
        child_block_interval: @child_block_interval,
        chain_start_parent_height: 1,
        block_submit_every_nth: 1,
        finality_threshold: 12,
        last_enqueued_block_at_height: 0
      )

    empty_with_gas_params = %{empty | formed_child_block_num: 5 * @child_block_interval, gas_price_to_use: 100}

    {:do_form_block, empty_with_gas_params} =
      Core.set_ethereum_status(empty_with_gas_params, 1, 3 * @child_block_interval, false)

    # assertions - to be explicit how state looks like
    child_block_mined = 3 * @child_block_interval
    assert {1, ^child_block_mined} = empty_with_gas_params.gas_price_adj_params.last_block_mined

    {:ok, %{empty: empty, empty_with_gas_params: empty_with_gas_params}}
  end

  # Create the block_queue new state with non-initial parameters like it was recovered from db after restart / crash
  # If top_mined_hash parameter is ommited it will be generated from mined_child_block_num
  defp recover(known_hashes, mined_child_block_num, top_mined_hash \\ nil) do
    top_mined_hash = top_mined_hash || "#{Kernel.inspect(trunc(mined_child_block_num / 1000))}"

    Core.new(
      mined_child_block_num: mined_child_block_num,
      known_hashes: known_hashes,
      top_mined_hash: top_mined_hash,
      parent_height: 10,
      child_block_interval: 1000,
      chain_start_parent_height: 1,
      block_submit_every_nth: 1,
      finality_threshold: 12,
      last_enqueued_block_at_height: 0
    )
  end

  describe "Block queue." do
    test "Requests correct block range on initialization" do
      assert [] == Core.child_block_nums_to_init_with(0, 0, @child_block_interval, 0)
      assert [] == Core.child_block_nums_to_init_with(0, 9, @child_block_interval, 0)
      assert [1000] == Core.child_block_nums_to_init_with(0, 1000, @child_block_interval, 0)
      assert [1000, 2000, 3000] == Core.child_block_nums_to_init_with(0, 3000, @child_block_interval, 0)
      assert [100, 200, 300, 400] == Core.child_block_nums_to_init_with(0, 400, 100, 0)
      assert [2000, 3000] == Core.child_block_nums_to_init_with(2000, 3000, @child_block_interval, 0)
    end

    test "Requests correct block range on initialization, non-zero finality threshold" do
      assert [] == Core.child_block_nums_to_init_with(0, 0, @child_block_interval, 2)
      assert [] == Core.child_block_nums_to_init_with(0, 9, @child_block_interval, 2)
      assert [1000] == Core.child_block_nums_to_init_with(0, 1000, @child_block_interval, 2)
      assert [1000, 2000, 3000] == Core.child_block_nums_to_init_with(0, 3000, @child_block_interval, 2)
      assert [2000, 3000, 4000, 5000] == Core.child_block_nums_to_init_with(4000, 5000, @child_block_interval, 2)
    end

    test "Recovers after restart to proper mined height" do
      assert [%{hash: "8", nonce: 8}, %{hash: "9", nonce: 9}] =
               [{5000, "5"}, {6000, "6"}, {7000, "7"}, {8000, "8"}, {9000, "9"}]
               |> recover(7000)
               |> elem(1)
               |> Core.get_blocks_to_submit()
    end

    test "Recovers after restart and talking to an un-synced geth" do
      # imagine restart after geth is nuked and hasn't caught up
      # testing against a disaster scenario where `BlockQueue` would start pushing old blocks again
      finality_threshold = 12
      mined_blknum = 6000
      range = Core.child_block_nums_to_init_with(mined_blknum, 9000, @child_block_interval, finality_threshold)
      known_hashes = ~w(1 2 3 4 5 6 7 8 9)

      {:ok, state} =
        Core.new(
          mined_child_block_num: mined_blknum,
          known_hashes: Enum.zip(range, known_hashes),
          top_mined_hash: "6",
          parent_height: 6,
          child_block_interval: @child_block_interval,
          chain_start_parent_height: 1,
          block_submit_every_nth: 1,
          finality_threshold: finality_threshold,
          last_enqueued_block_at_height: 0
        )

      assert [%{hash: "7", nonce: 7}, %{hash: "8", nonce: 8}, %{hash: "9", nonce: 9}] = Core.get_blocks_to_submit(state)

      # simulate geth catching up
      assert {:dont_form_block, new_state} = Core.set_ethereum_status(state, 7, 7000, true)
      assert [%{hash: "8", nonce: 8}, %{hash: "9", nonce: 9}] = Core.get_blocks_to_submit(new_state)
    end

    test "Recovers after restart even when only empty blocks were mined" do
      assert [%{hash: "0", nonce: 8}, %{hash: "0", nonce: 9}] =
               [{5000, "0"}, {6000, "0"}, {7000, "0"}, {8000, "0"}, {9000, "0"}]
               |> recover(7000, "0")
               |> elem(1)
               |> Core.get_blocks_to_submit()
    end

    test "Recovers properly for fresh world state" do
      {:ok, queue} =
        Core.new(
          mined_child_block_num: 0,
          known_hashes: [],
          top_mined_hash: <<0::size(256)>>,
          parent_height: 10,
          child_block_interval: 1000,
          chain_start_parent_height: 1,
          block_submit_every_nth: 1,
          finality_threshold: 12,
          last_enqueued_block_at_height: 0
        )

      assert [] == Core.get_blocks_to_submit(queue)
    end

    test "Won't recover if is contract is ahead of db" do
      assert {:error, :contract_ahead_of_db} ==
               Core.new(
                 mined_child_block_num: 0,
                 known_hashes: [],
                 top_mined_hash: <<1::size(256)>>,
                 parent_height: 10,
                 child_block_interval: 1000,
                 chain_start_parent_height: 1,
                 block_submit_every_nth: 1,
                 finality_threshold: 12,
                 last_enqueued_block_at_height: 0
               )
    end

    test "Won't recover if mined hash doesn't match with hash in db" do
      assert {:error, :hashes_dont_match} ==
               Core.new(
                 mined_child_block_num: 1000,
                 known_hashes: [{1000, <<2::size(256)>>}],
                 top_mined_hash: <<1::size(256)>>,
                 parent_height: 10,
                 child_block_interval: 1000,
                 chain_start_parent_height: 1,
                 block_submit_every_nth: 1,
                 finality_threshold: 12,
                 last_enqueued_block_at_height: 0
               )
    end

    test "Won't recover if mined block number and hash don't match with db" do
      assert {:error, :mined_blknum_not_found_in_db} ==
               Core.new(
                 mined_child_block_num: 2000,
                 known_hashes: [{1000, <<1::size(256)>>}],
                 top_mined_hash: <<2::size(256)>>,
                 parent_height: 10,
                 child_block_interval: 1000,
                 chain_start_parent_height: 1,
                 block_submit_every_nth: 1,
                 finality_threshold: 12,
                 last_enqueued_block_at_height: 0
               )
    end

    test "Won't recover if mined block number doesn't match with db" do
      assert {:error, :mined_blknum_not_found_in_db} ==
               Core.new(
                 mined_child_block_num: 2000,
                 known_hashes: [{1000, <<1::size(256)>>}],
                 top_mined_hash: <<1::size(256)>>,
                 parent_height: 10,
                 child_block_interval: 1000,
                 chain_start_parent_height: 1,
                 block_submit_every_nth: 1,
                 finality_threshold: 12,
                 last_enqueued_block_at_height: 0
               )
    end

    test "Will recover if there are blocks in db but none in root chain" do
      assert {:ok, state} = recover([{1000, "1"}], 0, <<0::size(256)>>)
      assert [%{hash: "1", nonce: 1}] = Core.get_blocks_to_submit(state)

      assert [%{hash: "1", nonce: 1}, %{hash: "2", nonce: 2}] =
               state |> Core.enqueue_block("2", 2 * @child_block_interval, 0) |> Core.get_blocks_to_submit()
    end

    test "Recovers after restart and is able to process more blocks" do
      assert [%{hash: "8", nonce: 8}, %{hash: "9", nonce: 9}, %{hash: "10", nonce: 10}] =
               [{5000, "5"}, {6000, "6"}, {7000, "7"}, {8000, "8"}, {9000, "9"}]
               |> recover(7000)
               |> elem(1)
               |> Core.enqueue_block("10", 10 * @child_block_interval, 0)
               |> Core.get_blocks_to_submit()
    end

    # TODO(pdobacz, fixing in a follow-up PR): looks like dupe of 3 tests above
    test "Recovery will fail if DB is corrupted" do
      assert {:error, :mined_blknum_not_found_in_db} == recover([{5000, "5"}, {6000, "6"}], 7000)
    end

    test "A new block is emitted ASAP", %{empty: empty} do
      assert [%{hash: "2", nonce: 2}] =
               empty
               |> Core.set_ethereum_status(0, 1000, false)
               |> elem(1)
               |> Core.enqueue_block("2", 2 * @child_block_interval, 0)
               |> Core.get_blocks_to_submit()
    end

    test "Produced child block numbers to form are as expected", %{empty: empty} do
      assert {:dont_form_block, queue} = Core.set_ethereum_status(empty, 0, 0, false)

      assert {:do_form_block, _} = Core.set_ethereum_status(queue, 1, 0, false)
    end

    test "Produced child blocks to form aren't repeated, if none are enqueued", %{empty: empty} do
      assert {:do_form_block, queue} = Core.set_ethereum_status(empty, 1, 0, false)

      assert {:dont_form_block, _} = Core.set_ethereum_status(queue, 1, 0, false)
    end

    test "Ethereum updates and enqueues can go interleaved", %{empty: empty} do
      # no enqueue after Core.set_ethereum_status(1) so don't form block
      assert {:dont_form_block, queue} =
               empty
               |> Core.set_ethereum_status(1, 0, false)
               |> elem(1)
               |> Core.set_ethereum_status(2, 0, false)
               |> elem(1)
               |> Core.set_ethereum_status(3, 0, false)

      assert {:do_form_block, queue} =
               queue
               |> Core.enqueue_block("1", @child_block_interval, 0)
               |> Core.set_ethereum_status(4, 0, false)

      assert {:dont_form_block, queue} =
               queue
               |> Core.set_ethereum_status(5, 0, false)

      assert {:do_form_block, _queue} =
               queue
               |> Core.enqueue_block("2", 2 * @child_block_interval, 0)
               |> Core.set_ethereum_status(6, 0, false)
    end

    # NOTE: theoretically the back off is ver hard to get - testing if this rare occasion doesn't make the state weird
    test "Ethereum updates can back off and jump independent from enqueues", %{empty: empty} do
      # no enqueue after Core.set_ethereum_status(2) so don't form block
      assert {:dont_form_block, queue} =
               empty
               |> Core.set_ethereum_status(1, 0, false)
               |> elem(1)
               |> Core.set_ethereum_status(2, 0, false)
               |> elem(1)
               |> Core.set_ethereum_status(1, 0, false)

      assert {:do_form_block, queue} =
               queue
               |> Core.enqueue_block("1", @child_block_interval, 0)
               |> Core.set_ethereum_status(1, 0, false)

      assert {:dont_form_block, queue} =
               queue
               |> Core.enqueue_block("2", 2 * @child_block_interval, 1)
               |> Core.set_ethereum_status(1, 0, false)

      assert {:do_form_block, _queue} =
               queue
               |> Core.set_ethereum_status(2, 0, false)
    end

    test "Block is not enqueued when number of enqueued block does not match expected block number", %{empty: empty} do
      {:error, :unexpected_block_number} = Core.enqueue_block(empty, "1", 2 * @child_block_interval, 0)
    end

    test "Produced blocks submission requests have nonces in order", %{empty: empty} do
      assert [_, %{nonce: 2}] =
               empty
               |> Core.set_ethereum_status(0, 0, false)
               |> elem(1)
               |> Core.enqueue_block("1", @child_block_interval, 0)
               |> Core.enqueue_block("2", 2 * @child_block_interval, 0)
               |> Core.get_blocks_to_submit()
    end

    test "Block generation is driven by last enqueued block Ethereum height and if block is empty or not", %{
      empty: empty
    } do
      assert {:dont_form_block, _} =
               empty
               |> Core.set_ethereum_status(0, 0, false)

      assert {:dont_form_block, _} =
               empty
               |> Core.set_ethereum_status(1, 0, true)

      assert {:do_form_block, queue} =
               empty
               |> Core.set_ethereum_status(1, 0, false)

      assert {:dont_form_block, _} =
               queue
               |> Core.enqueue_block("1", @child_block_interval, 0)
               |> Core.set_ethereum_status(0, 0, false)

      assert {:dont_form_block, _} =
               queue
               |> Core.enqueue_block("1", @child_block_interval, 1)
               |> Core.set_ethereum_status(1, 0, false)

      assert {:dont_form_block, _} =
               queue
               |> Core.enqueue_block("1", @child_block_interval, 0)
               |> Core.set_ethereum_status(1, 0, true)

      # Ethereum advanced since enqueue and block isn't empty -> order forming of next block
      assert {:do_form_block, queue} =
               queue
               |> Core.enqueue_block("1", @child_block_interval, 0)
               |> Core.set_ethereum_status(1, 0, false)

      # no enqueue
      assert {:dont_form_block, queue} =
               queue
               |> Core.set_ethereum_status(1, 0, false)

      assert {:dont_form_block, _} =
               queue
               |> Core.enqueue_block("2", 2 * @child_block_interval, 1)
               |> Core.set_ethereum_status(1, 0, false)

      assert {:do_form_block, _} =
               queue
               |> Core.enqueue_block("2", 2 * @child_block_interval, 1)
               |> Core.set_ethereum_status(2, 0, false)
    end

    test "Smoke test", %{empty: empty} do
      assert {:dont_form_block, queue} =
               empty
               |> Core.set_ethereum_status(0, 0, false)
               |> elem(1)
               |> Core.enqueue_block("1", 1 * @child_block_interval, 0)
               |> Core.enqueue_block("2", 2 * @child_block_interval, 1)
               |> Core.enqueue_block("3", 3 * @child_block_interval, 2)
               |> Core.enqueue_block("4", 4 * @child_block_interval, 3)
               |> Core.enqueue_block("5", 5 * @child_block_interval, 4)
               |> Core.set_ethereum_status(3, 2000, false)

      assert [%{hash: "3", nonce: 3}, %{hash: "4", nonce: 4}, %{hash: "5", nonce: 5}] =
               queue |> Core.get_blocks_to_submit()
    end

    # helper function makes a chain that have size blocks
    defp make_chain(base, size) do
      if size > 0,
        do:
          Enum.reduce(1..size, base, fn hash, state ->
            Core.enqueue_block(state, hash, hash * @child_block_interval, hash)
          end),
        else: base
    end

    defp size(state) do
      state |> :erlang.term_to_binary() |> byte_size()
    end

    test "Old blocks are removed, but only after finality_threshold", %{empty: empty} do
      long_length = 1_000
      short_length = 4

      # make chains where no child blocks ever get mined to bloat the object
      long = make_chain(empty, long_length)
      long_size = size(long)

      empty_size = size(empty)
      one_block_size = size(make_chain(empty, 1)) - empty_size

      # sanity check if we haven't removed blocks to early
      assert long_size - empty_size >= one_block_size * long_length

      # here we suddenly mine the child blocks and the remove should happen
      long_mined_size =
        long
        |> Core.set_ethereum_status(long_length, (long_length - short_length) * 1000, false)
        |> elem(1)
        |> size()

      assert long_mined_size - empty_size < (short_length + empty.finality_threshold + 1) * one_block_size
    end
  end

  describe "Adjusting gas price" do
    # TODO: rewrite these tests to not use the internal `gas_price_adj_params` field - ask for submissions via public
    #       interface instead

    test "Calling with empty state will initailize gas information", %{empty: empty} do
      {_, state} = Core.set_ethereum_status(empty, 1, 0, false)

      gas_params = state.gas_price_adj_params
      assert gas_params != nil
      assert {1, 0} == gas_params.last_block_mined
    end

    test "Calling with current ethereum height doesn't change the gas params", %{
      empty_with_gas_params: empty_with_gas_params
    } do
      state = empty_with_gas_params

      current_height = state.parent_height
      current_price = state.gas_price_to_use
      current_params = state.gas_price_adj_params

      {_, newstate} = Core.set_ethereum_status(state, 1, 0, false)

      assert current_height == newstate.parent_height
      assert current_price == newstate.gas_price_to_use
      assert current_params == newstate.gas_price_adj_params
    end

    test "Gas price is lowered when ethereum blocks gap isn't filled", %{empty_with_gas_params: empty_with_gas_params} do
      state = Core.enqueue_block(empty_with_gas_params, <<0>>, 6 * @child_block_interval, 1)
      current_price = state.gas_price_to_use

      {_, newstate} = Core.set_ethereum_status(state, 2, 0, false)

      assert current_price > newstate.gas_price_to_use

      # assert the actual gas price based on parameters value - test could fail if params or calculation will change
      assert 90 == newstate.gas_price_to_use
    end

    test "Gas price is raised when ethereum blocks gap is filled", %{empty_with_gas_params: empty_with_gas_params} do
      state = empty_with_gas_params
      current_price = state.gas_price_to_use
      eth_gap = state.gas_price_adj_params.eth_gap_without_child_blocks

      {:do_form_block, newstate} =
        state
        |> Core.enqueue_block(<<0>>, 6 * @child_block_interval, 1)
        |> Core.set_ethereum_status(1 + eth_gap, 0, false)

      assert current_price < newstate.gas_price_to_use

      # assert the actual gas price based on parameters value - test could fail if params or calculation will change
      assert 200 == newstate.gas_price_to_use
    end

    test "Gas price is lowered and then raised when ethereum blocks gap gets filled", %{
      empty_with_gas_params: empty_with_gas_params
    } do
      state = Core.enqueue_block(empty_with_gas_params, <<6>>, 6 * @child_block_interval, 1)
      gas_params = %{state.gas_price_adj_params | eth_gap_without_child_blocks: 3}
      state1 = %{state | gas_price_adj_params: gas_params}

      {_, state2} = Core.set_ethereum_status(state1, 4, 5 * @child_block_interval, false)

      assert state.gas_price_to_use > state2.gas_price_to_use
      state2 = Core.enqueue_block(state2, <<6>>, 7 * @child_block_interval, 4)

      {_, state3} = Core.set_ethereum_status(state2, 6, 5 * @child_block_interval, false)

      assert state2.gas_price_to_use > state3.gas_price_to_use

      # Now the ethereum block gap without child blocks is reached
      {_, state4} = Core.set_ethereum_status(state2, 7, 5 * @child_block_interval, false)

      assert state3.gas_price_to_use < state4.gas_price_to_use
    end

    test "Gas price calculation cannot be raised above limit", %{empty_with_gas_params: state} do
      expected_max_price = 5 * state.gas_price_to_use
      gas_params = %{state.gas_price_adj_params | gas_price_raising_factor: 10, max_gas_price: expected_max_price}
      state = %{state | gas_price_adj_params: gas_params} |> Core.enqueue_block(<<0>>, 6 * @child_block_interval, 1)

      # Despite Ethereum height changing multiple times, gas price does not grow since no new blocks are mined
      Enum.reduce(4..100, state, fn eth_height, state ->
        {_, state} = Core.set_ethereum_status(state, eth_height, 2 * @child_block_interval, false)
        assert expected_max_price == state.gas_price_to_use
        state
      end)
    end

    test "Gas price doesn't change if no new blocks are formed, and is lowered the moment there's one",
         %{empty_with_gas_params: state} do
      expected_price = state.gas_price_to_use
      current_blknum = 5 * @child_block_interval
      next_blknum = 6 * @child_block_interval

      # Despite Ethereum height changing multiple times, gas price does not grow since no new blocks are mined
      Enum.reduce(4..100, state, fn eth_height, state ->
        {_, state} = Core.set_ethereum_status(state, eth_height, current_blknum, false)
        assert expected_price == state.gas_price_to_use
        state
      end)

      {_, state} =
        state |> Core.enqueue_block(<<0>>, next_blknum, 1) |> Core.set_ethereum_status(1000, current_blknum, false)

      assert expected_price > state.gas_price_to_use
    end
  end

  describe "Processing submission results from geth" do
    test "everything might be ok" do
      [submission] = recover([{1000, "1"}], 0, <<0::size(256)>>) |> elem(1) |> Core.get_blocks_to_submit()
      # no change in mined blknum
      assert :ok = Core.process_submit_result(submission, {:ok, <<0::160>>}, 1000)
      # arbitrary ignored change in mined blknum
      assert :ok = Core.process_submit_result(submission, {:ok, <<0::160>>}, 0)
      assert :ok = Core.process_submit_result(submission, {:ok, <<0::160>>}, 2000)
    end

    test "benign reports / warnings from geth" do
      [submission] = recover([{1000, "1"}], 0, <<0::size(256)>>) |> elem(1) |> Core.get_blocks_to_submit()
      # no change in mined blknum
      assert :ok = Core.process_submit_result(submission, @known_transaction_response, 1000)

      assert :ok = Core.process_submit_result(submission, @replacement_transaction_response, 1000)
    end

    test "benign nonce too low error - related to our tx being mined, since the mined blknum advanced" do
      [submission] = recover([{1000, "1"}], 0, <<0::size(256)>>) |> elem(1) |> Core.get_blocks_to_submit()
      assert :ok = Core.process_submit_result(submission, @nonce_too_low_response, 1000)
      assert :ok = Core.process_submit_result(submission, @nonce_too_low_response, 2000)
    end

    test "real nonce too low error" do
      [submission] = recover([{1000, "1"}], 0, <<0::size(256)>>) |> elem(1) |> Core.get_blocks_to_submit()

      # the new mined child block number is not the one we submitted, so we expect an error an error log
      assert capture_log(fn ->
               assert {:error, :nonce_too_low} = Core.process_submit_result(submission, @nonce_too_low_response, 0)
             end) =~ "[error]"

      assert capture_log(fn ->
               assert {:error, :nonce_too_low} = Core.process_submit_result(submission, @nonce_too_low_response, 90)
             end) =~ "[error]"
    end

    test "other fatal errors" do
      [submission] = recover([{1000, "1"}], 0, <<0::size(256)>>) |> elem(1) |> Core.get_blocks_to_submit()

      # the new mined child block number is not the one we submitted, so we expect an error an error log
      assert capture_log(fn ->
               assert {:error, :account_locked} = Core.process_submit_result(submission, @account_locked_response, 0)
             end) =~ "[error]"
    end

    test "gas price change only, when try to push blocks", %{empty_with_gas_params: state} do
      gas_price = state.gas_price_to_use

      state =
        Enum.reduce(4..10, state, fn eth_height, state ->
          {_, state} = Core.set_ethereum_status(state, eth_height, 0, false)
          assert gas_price == state.gas_price_to_use
          state
        end)

      state = state |> Core.enqueue_block(<<0>>, 6 * @child_block_interval, 1)
      {_, state} = Core.set_ethereum_status(state, 101, 0, false)
      assert state.gas_price_to_use > gas_price
    end

    test "gas price changes only, when etherum advanses", %{empty_with_gas_params: state} do
      gas_price = state.gas_price_to_use
      eth_height = 0

      state =
        Enum.reduce(6..20, state, fn child_number, state ->
          {_, state} =
            state
            |> Core.enqueue_block(<<0>>, child_number * @child_block_interval, 1)
            |> Core.set_ethereum_status(eth_height, 0, false)

          assert gas_price == state.gas_price_to_use
          state
        end)

      {_, state} = Core.set_ethereum_status(state, eth_height + 1, 0, false)
      assert state.gas_price_to_use < gas_price
    end

    test "gas price doesn't change when ethereum backs off, even if block in queue", %{empty_with_gas_params: state} do
      eth_height = 100
      {_, state} = Core.set_ethereum_status(state, eth_height, 0, false)
      gas_price = state.gas_price_to_use

      state
      |> Core.enqueue_block(<<0>>, 6 * @child_block_interval, 1)
      |> Core.enqueue_block(<<0>>, 7 * @child_block_interval, 1)
      |> Core.enqueue_block(<<0>>, 8 * @child_block_interval, 1)

      Enum.reduce(80..(eth_height - 1), state, fn eth_height, state ->
        {_, state} = Core.set_ethereum_status(state, eth_height, 0, false)
        assert gas_price == state.gas_price_to_use
        state
      end)
    end
  end
end
