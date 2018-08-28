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

defmodule OMG.API.BlockQueue.CoreTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import OMG.API.BlockQueue.Core

  @child_block_interval 1000

  def hashes(blocks) do
    for block <- blocks, do: block.hash
  end

  def empty do
    {:ok, state} =
      new(
        mined_child_block_num: 0,
        known_hashes: [],
        top_mined_hash: <<0::256>>,
        parent_height: 1,
        child_block_interval: @child_block_interval,
        chain_start_parent_height: 1,
        submit_period: 1,
        finality_threshold: 12
      )

    state
  end

  @doc """
  Create the block_queue new state with non-initial parameters like it was recovered from db after restart / crash
  If top_mined_hash parameter is ommited it will be generated from mined_child_block_num
  """
  def recover(known_hashes, mined_child_block_num, top_mined_hash \\ nil) do
    top_mined_hash = top_mined_hash || "#{Kernel.inspect(trunc(mined_child_block_num / 1000))}"

    new(
      mined_child_block_num: mined_child_block_num,
      known_hashes: known_hashes,
      top_mined_hash: top_mined_hash,
      parent_height: 10,
      child_block_interval: 1000,
      chain_start_parent_height: 1,
      submit_period: 1,
      finality_threshold: 12
    )
  end

  describe "Block queue." do
    test "Requests correct block range on initialization" do
      assert [] == child_block_nums_to_init_with(0)
      assert [] == child_block_nums_to_init_with(99)
      assert [1000] == child_block_nums_to_init_with(1000)
      assert [1000, 2000, 3000] == child_block_nums_to_init_with(3000)
    end

    test "Recovers after restart to proper mined height" do
      assert ["8", "9"] =
               [{5000, "5"}, {6000, "6"}, {7000, "7"}, {8000, "8"}, {9000, "9"}]
               |> recover(7000)
               |> elem(1)
               |> get_blocks_to_submit()
               |> hashes()
    end

    test "Recovers after restart even when only empty blocks were mined" do
      assert ["0", "0"] ==
               [{5000, "0"}, {6000, "0"}, {7000, "0"}, {8000, "0"}, {9000, "0"}]
               |> recover(7000, "0")
               |> elem(1)
               |> get_blocks_to_submit()
               |> hashes()
    end

    test "Recovers properly for fresh world state" do
      {:ok, queue} =
        new(
          mined_child_block_num: 0,
          known_hashes: [],
          top_mined_hash: <<0::size(256)>>,
          parent_height: 10,
          child_block_interval: 1000,
          chain_start_parent_height: 1,
          submit_period: 1,
          finality_threshold: 12
        )

      assert [] ==
               queue
               |> get_blocks_to_submit()
               |> hashes()
    end

    test "Won't recover if is contract is ahead of db" do
      assert {:error, :contract_ahead_of_db} ==
               new(
                 mined_child_block_num: 0,
                 known_hashes: [],
                 top_mined_hash: <<1::size(256)>>,
                 parent_height: 10,
                 child_block_interval: 1000,
                 chain_start_parent_height: 1,
                 submit_period: 1,
                 finality_threshold: 12
               )
    end

    test "Won't recover if mined hash doesn't match with hash in db" do
      assert {:error, :hashes_dont_match} ==
               new(
                 mined_child_block_num: 1000,
                 known_hashes: [{1000, <<2::size(256)>>}],
                 top_mined_hash: <<1::size(256)>>,
                 parent_height: 10,
                 child_block_interval: 1000,
                 chain_start_parent_height: 1,
                 submit_period: 1,
                 finality_threshold: 12
               )
    end

    test "Won't recover if mined block number doesn't match with db" do
      assert {:error, :mined_blknum_not_found_in_db} ==
               new(
                 mined_child_block_num: 2000,
                 known_hashes: [{1000, <<1::size(256)>>}],
                 top_mined_hash: <<2::size(256)>>,
                 parent_height: 10,
                 child_block_interval: 1000,
                 chain_start_parent_height: 1,
                 submit_period: 1,
                 finality_threshold: 12
               )
    end

    test "Recovers after restart and is able to process more blocks" do
      assert ["8", "9", "10"] ==
               [{5000, "5"}, {6000, "6"}, {7000, "7"}, {8000, "8"}, {9000, "9"}]
               |> recover(7000)
               |> elem(1)
               |> enqueue_block("10", 10 * @child_block_interval)
               |> get_blocks_to_submit()
               |> hashes()
    end

    test "Recovery will fail if DB is corrupted" do
      assert {:error, :mined_blknum_not_found_in_db} == recover([{5000, "5"}, {6000, "6"}], 7000)
    end

    test "No submitBlock will be sent until properly initialized" do
      catch_error(get_blocks_to_submit(new()))
    end

    test "A new block is emitted ASAP" do
      assert ["2"] ==
               empty()
               |> set_ethereum_status(0, 1000)
               |> elem(1)
               |> enqueue_block("2", 2 * @child_block_interval)
               |> get_blocks_to_submit()
               |> hashes()
    end

    @tag :basic
    test "Produced child block numbers to form are as expected" do
      assert {:dont_form_block, queue} =
               empty()
               |> set_ethereum_status(1, 0)

      assert {:do_form_block, _} =
               queue
               |> set_ethereum_status(2, 0)
    end

    test "Produced child blocks to form aren't repeated, if none are enqueued" do
      assert {:do_form_block, queue} =
               empty()
               |> set_ethereum_status(2, 0)

      assert {:dont_form_block, _} =
               queue
               |> set_ethereum_status(3, 0)
    end

    test "Ethereum updates and enqueues can go interleaved" do
      # no enqueue after set_ethereum_status(1) so don't form block
      assert {:dont_form_block, queue} =
               empty()
               |> set_ethereum_status(1, 0)
               |> elem(1)
               |> set_ethereum_status(2, 0)
               |> elem(1)
               |> set_ethereum_status(3, 0)

      assert {:do_form_block, queue} =
               queue
               |> enqueue_block("1", @child_block_interval)
               |> set_ethereum_status(4, 0)

      assert {:dont_form_block, queue} =
               queue
               |> set_ethereum_status(5, 0)

      assert {:do_form_block, _queue} =
               queue
               |> enqueue_block("2", 2 * @child_block_interval)
               |> set_ethereum_status(6, 0)
    end

    # NOTE: theoretically the back off is ver hard to get - testing if this rare occasion doesn't make the state weird
    test "Ethereum updates can back off and jump independent from enqueues" do
      # no enqueue after set_ethereum_status(2) so don't form block
      assert {:dont_form_block, queue} =
               empty()
               |> set_ethereum_status(1, 0)
               |> elem(1)
               |> set_ethereum_status(2, 0)
               |> elem(1)
               |> set_ethereum_status(1, 0)

      assert {:do_form_block, queue} =
               queue
               |> enqueue_block("1", @child_block_interval)
               |> set_ethereum_status(3, 0)

      assert {:dont_form_block, queue} =
               queue
               |> enqueue_block("2", 2 * @child_block_interval)
               |> set_ethereum_status(2, 0)

      assert {:do_form_block, _queue} =
               queue
               |> set_ethereum_status(4, 0)
    end

    test "Block is not enqueued when number of enqueued block does not match expected block number" do
      {:error, :unexpected_block_number} =
        empty()
        |> enqueue_block("1", 2 * @child_block_interval)
    end

    test "Produced blocks submission requests have nonces in order" do
      assert [_, %{nonce: 2}] =
               empty()
               |> set_ethereum_status(0, 0)
               |> elem(1)
               |> enqueue_block("1", @child_block_interval)
               |> enqueue_block("2", 2 * @child_block_interval)
               |> get_blocks_to_submit()
    end

    test "Block generation is driven by Ethereum height" do
      assert {:dont_form_block, queue} =
               empty()
               |> set_ethereum_status(1, 0)

      assert {:dont_form_block, queue} =
               queue
               |> enqueue_block("1", @child_block_interval)
               |> set_ethereum_status(0, 0)

      assert {:dont_form_block, queue} =
               queue
               |> set_ethereum_status(1, 0)

      assert {:dont_form_block, queue} =
               queue
               |> set_ethereum_status(2, 0)

      assert {:dont_form_block, _} =
               queue
               |> enqueue_block("2", 2 * @child_block_interval)
               |> set_ethereum_status(2, 0)
    end

    test "Smoke test" do
      assert {:dont_form_block, queue} =
               empty()
               |> set_ethereum_status(0, 0)
               |> elem(1)
               |> enqueue_block("1", 1 * @child_block_interval)
               |> enqueue_block("2", 2 * @child_block_interval)
               |> enqueue_block("3", 3 * @child_block_interval)
               |> enqueue_block("4", 4 * @child_block_interval)
               |> enqueue_block("5", 5 * @child_block_interval)
               |> set_ethereum_status(3, 2000)

      assert ["3", "4", "5"] =
               queue
               |> get_blocks_to_submit()
               |> hashes()
    end

    test "Old blocks are GCd, but only after they're mined" do
      long_length = 1_000
      short_length = 100

      # make chains where no child blocks ever get mined to bload the object
      long = long_length |> make_chain()
      long_size = long |> :erlang.term_to_binary() |> byte_size()
      short_size = short_length |> make_chain() |> :erlang.term_to_binary() |> byte_size()

      # sanity check if we haven't GCd too early
      assert long_size > long_length / short_length * short_size

      # here we suddenly mine the child blocks and the GCing should happen
      long_mined_size =
        long
        |> set_ethereum_status(long_length, (long_length - short_length) * 1000)
        |> elem(1)
        |> :erlang.term_to_binary()
        |> byte_size()

      assert_in_delta(long_mined_size / short_size, 1, 0.2)
    end
  end

  # helper function for the GCing test, makes a long chain
  defp make_chain(length) do
    {:dont_form_block, queue} =
      2..length
      |> Enum.reduce(empty(), fn hash, state ->
        {:do_form_block, state} = set_ethereum_status(state, hash, 0)
        enqueue_block(state, hash, (hash - 1) * @child_block_interval)
      end)
      |> set_ethereum_status(length, 0)

    queue
  end

  defp empty_with_gas_params do
    state = %{empty() | formed_child_block_num: 5, gas_price_to_use: 100}

    {:dont_form_block, state} =
      state
      |> set_ethereum_status(1, 3)

    # assertions - to be explicit how state looks like
    assert {1, 3} = state.gas_price_adj_params.last_block_mined

    state
  end

  describe "Adjusting gas price" do
    test "Calling with empty state will initailize gas information" do
      {:dont_form_block, state} =
        empty()
        |> set_ethereum_status(1, 0)

      gas_params = state.gas_price_adj_params
      assert gas_params != nil
      assert {1, 0} == gas_params.last_block_mined
    end

    test "Calling with current ethereum height doesn't change the gas params" do
      state = empty_with_gas_params()

      current_height = state.parent_height
      current_price = state.gas_price_to_use
      current_params = state.gas_price_adj_params

      {:dont_form_block, newstate} =
        state
        |> set_ethereum_status(1, 0)

      assert current_height == newstate.parent_height
      assert current_price == newstate.gas_price_to_use
      assert current_params == newstate.gas_price_adj_params
    end

    test "Gas price is lowered when ethereum blocks gap isn't filled" do
      state = empty_with_gas_params()
      current_price = state.gas_price_to_use

      {:do_form_block, newstate} =
        state
        |> set_ethereum_status(2, 0)

      assert current_price > newstate.gas_price_to_use

      # assert the actual gas price based on parameters value - test could fail if params or calculation will change
      assert 90 == newstate.gas_price_to_use
    end

    test "Gas price is raised when ethereum blocks gap is filled" do
      state = empty_with_gas_params()
      current_price = state.gas_price_to_use
      eth_gap = state.gas_price_adj_params.eth_gap_without_child_blocks

      {:do_form_block, newstate} =
        state
        |> set_ethereum_status(1 + eth_gap, 0)

      assert current_price < newstate.gas_price_to_use

      # assert the actual gas price based on parameters value - test could fail if params or calculation will change
      assert 200 == newstate.gas_price_to_use
    end

    test "Gas price is lowered and then raised when ethereum blocks gap gets filled" do
      state = empty_with_gas_params()
      gas_params = %{state.gas_price_adj_params | eth_gap_without_child_blocks: 3}
      state1 = %{state | gas_price_adj_params: gas_params}

      {:do_form_block, state2} =
        state1
        |> set_ethereum_status(2, 0)

      assert state.gas_price_to_use > state2.gas_price_to_use

      {:dont_form_block, state3} =
        state2
        |> set_ethereum_status(3, 0)

      assert state2.gas_price_to_use > state3.gas_price_to_use

      # Now the ethereum block gap without child blocks is reached
      {:dont_form_block, state4} =
        state2
        |> set_ethereum_status(4, 0)

      assert state3.gas_price_to_use < state4.gas_price_to_use
    end

    test "Gas price calculation cannot be raised above limit" do
      state = empty_with_gas_params()
      expected_max_price = 5 * state.gas_price_to_use
      gas_params = %{state.gas_price_adj_params | gas_price_raising_factor: 10, max_gas_price: expected_max_price}
      state1 = %{state | gas_price_adj_params: gas_params}
      eth_gap = state1.gas_price_adj_params.eth_gap_without_child_blocks

      {:do_form_block, newstate} =
        state1
        |> set_ethereum_status(1 + eth_gap, 0)

      assert expected_max_price == newstate.gas_price_to_use
    end
  end
end
