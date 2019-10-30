# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.BlockQueue.BlockQueueCoreTest do
  @moduledoc false
  use ExUnitFixtures
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import OMG.ChildChain.BlockTestHelper

  alias OMG.ChildChain.BlockQueue.BlockSubmission
  alias OMG.ChildChain.BlockQueue.BlockQueueCore
  alias OMG.ChildChain.BlockQueue.BlockQueueInitializer
  alias OMG.ChildChain.BlockQueue.BlockQueueSubmitter
  alias OMG.ChildChain.BlockQueue.BlockQueueState
  alias OMG.ChildChain.BlockQueue.GasPriceAdjustment

  alias OMG.ChildChain.FakeRootChain

  alias OMG.Block

  doctest OMG.ChildChain.BlockQueue.BlockQueueCore

  @child_block_interval 1000

  # responses from geth to simulate what we're getting from geth in `BlockQueue`
  @known_transaction_response {:error, %{"code" => -32_000, "message" => "known transaction tx"}}
  @replacement_transaction_response {:error, %{"code" => -32_000, "message" => "replacement transaction underpriced"}}
  @nonce_too_low_response {:error, %{"code" => -32_000, "message" => "nonce too low"}}
  @account_locked_response {:error, %{"code" => -32_000, "message" => "authentication needed: password or unlock"}}

  deffixture empty do
    {:ok, state} =
      BlockQueueCore.init(%{
        parent_height: 1,
        mined_child_block_num: 0,
        chain_start_parent_height: 1,
        child_block_interval: @child_block_interval,
        last_enqueued_block_at_height: 0,
        finality_threshold: 12,
        minimal_enqueue_block_gap: 1,
        known_hashes: [],
        top_mined_hash: <<0::256>>
      })

    state
  end

  deffixture empty_with_gas_params(empty) do
    state = %{empty | formed_child_block_num: 5 * @child_block_interval, gas_price_to_use: 100}

    {:do_not_form_block, state} =
      state
      |> BlockQueueCore.sync_with_ethereum(%{
        ethereum_height: 1,
        mined_child_block_num: 3 * @child_block_interval,
        is_empty_block: false
      })

    # assertions - to be explicit how state looks like
    child_block_mined = 3 * @child_block_interval
    assert {1, ^child_block_mined} = state.gas_price_adj_params.last_block_mined

    state
  end

  describe "init/1" do
    test "recovers properly for fresh world state" do
      {:ok, queue} =
        BlockQueueCore.init(%{
          mined_child_block_num: 0,
          known_hashes: [],
          top_mined_hash: <<0::size(256)>>,
          parent_height: 10,
          child_block_interval: 1000,
          chain_start_parent_height: 1,
          minimal_enqueue_block_gap: 1,
          finality_threshold: 12,
          last_enqueued_block_at_height: 0
        })

      assert [] == BlockQueueSubmitter.get_blocks_to_submit(queue)
    end

    test "recovers if there are blocks in db but none in root chain" do
      assert {:ok, state} = recover_state([{1000, "1"}], 0, <<0::size(256)>>)

      assert [%{hash: "1", nonce: 1}] = BlockQueueSubmitter.get_blocks_to_submit(state)

      assert [%{hash: "1", nonce: 1}, %{hash: "2", nonce: 2}] =
               state
               |> BlockQueueCore.enqueue_block(%{hash: "2", number: 2 * @child_block_interval}, 0)
               |> BlockQueueSubmitter.get_blocks_to_submit()
    end

    test "recovers after restart and is able to process more blocks" do
      assert [%{hash: "8", nonce: 8}, %{hash: "9", nonce: 9}, %{hash: "10", nonce: 10}] =
               [{5000, "5"}, {6000, "6"}, {7000, "7"}, {8000, "8"}, {9000, "9"}]
               |> recover_state(7000)
               |> elem(1)
               |> BlockQueueCore.enqueue_block(%{hash: "10", number: 10 * @child_block_interval}, 0)
               |> BlockQueueSubmitter.get_blocks_to_submit()
    end

    test "fails to recover if DB is corrupted" do
      assert {:error, :mined_blknum_not_found_in_db} == recover_state([{5000, "5"}, {6000, "6"}], 7000)
    end

    test "does not recover if is contract is ahead of db" do
      assert {:error, :contract_ahead_of_db} ==
               BlockQueueCore.init(%{
                 mined_child_block_num: 0,
                 known_hashes: [],
                 top_mined_hash: <<1::size(256)>>,
                 parent_height: 10,
                 child_block_interval: 1000,
                 chain_start_parent_height: 1,
                 minimal_enqueue_block_gap: 1,
                 finality_threshold: 12,
                 last_enqueued_block_at_height: 0
               })
    end

    test "does not recover if mined hash doesn't match with hash in db" do
      assert {:error, :hashes_dont_match} ==
               BlockQueueCore.init(%{
                 mined_child_block_num: 1000,
                 known_hashes: [{1000, <<2::size(256)>>}],
                 top_mined_hash: <<1::size(256)>>,
                 parent_height: 10,
                 child_block_interval: 1000,
                 chain_start_parent_height: 1,
                 minimal_enqueue_block_gap: 1,
                 finality_threshold: 12,
                 last_enqueued_block_at_height: 0
               })
    end

    test "does not recover if mined block number doesn't match with db" do
      assert {:error, :mined_blknum_not_found_in_db} ==
               BlockQueueCore.init(%{
                 mined_child_block_num: 2000,
                 known_hashes: [{1000, <<1::size(256)>>}],
                 top_mined_hash: <<2::size(256)>>,
                 parent_height: 10,
                 child_block_interval: 1000,
                 chain_start_parent_height: 1,
                 minimal_enqueue_block_gap: 1,
                 finality_threshold: 12,
                 last_enqueued_block_at_height: 0
               })
    end
  end

  describe "sync_with_ethereum/2" do
    @tag :basic
    @tag fixtures: [:empty]
    test "produces child block numbers as expected", %{empty: empty} do
      assert {:do_not_form_block, queue} =
               empty
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 1,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })

      assert {:do_form_block, _} =
               queue
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 2,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })
    end

    @tag fixtures: [:empty]
    test "removes old blocks after the finality_threshold has been reached", %{empty: empty} do
      long_length = 1_000
      short_length = 4

      # make chains where no child blocks ever get mined to bloat the object
      long = make_chain(empty, long_length)
      long_size = long |> size()

      empty_size = empty |> size()
      one_block_size = (make_chain(empty, 1) |> size()) - empty_size

      # sanity check if we haven't removed blocks to early
      assert long_size - empty_size >= one_block_size * long_length

      # here we suddenly mine the child blocks and the remove should happen
      long_mined_size =
        long
        |> BlockQueueCore.sync_with_ethereum(%{
          ethereum_height: long_length,
          mined_child_block_num: (long_length - short_length) * 1000,
          is_empty_block: false
        })
        |> elem(1)
        |> size()

      assert long_mined_size - empty_size < (short_length + empty.finality_threshold + 1) * one_block_size
    end

    # TODO: rewrite these tests to not use the internal `gas_price_adj_params` field - ask for submissions via public
    #       interface instead
    @tag fixtures: [:empty]
    test "initializes with empty state sets the gas information", %{empty: empty} do
      {:do_not_form_block, state} =
        empty
        |> BlockQueueCore.sync_with_ethereum(%{
          ethereum_height: 1,
          mined_child_block_num: 0,
          is_empty_block: false
        })

      gas_params = state.gas_price_adj_params
      assert gas_params != nil
      assert {1, 0} == gas_params.last_block_mined
    end

    @tag fixtures: [:empty_with_gas_params]
    test "does not change the gas params when ethereum height didn't change", %{
      empty_with_gas_params: empty_with_gas_params
    } do
      state = empty_with_gas_params

      current_height = state.parent_height
      current_price = state.gas_price_to_use
      current_params = state.gas_price_adj_params

      {:do_not_form_block, newstate} =
        state
        |> BlockQueueCore.sync_with_ethereum(%{
          ethereum_height: 1,
          mined_child_block_num: 0,
          is_empty_block: false
        })

      assert current_height == newstate.parent_height
      assert current_price == newstate.gas_price_to_use
      assert current_params == newstate.gas_price_adj_params
    end

    @tag fixtures: [:empty_with_gas_params]
    test "lowers the gas price when ethereum blocks gap isn't filled", %{empty_with_gas_params: empty_with_gas_params} do
      state =
        empty_with_gas_params |> BlockQueueCore.enqueue_block(%{hash: <<0>>, number: 6 * @child_block_interval}, 1)

      current_price = state.gas_price_to_use

      {:do_not_form_block, newstate} =
        state
        |> BlockQueueCore.sync_with_ethereum(%{
          ethereum_height: 2,
          mined_child_block_num: 0,
          is_empty_block: false
        })

      assert current_price > newstate.gas_price_to_use

      # assert the actual gas price based on parameters value - test could fail if params or calculation will change
      assert 90 == newstate.gas_price_to_use
    end

    @tag fixtures: [:empty_with_gas_params]
    test "raises the gas price when ethereum blocks gap is filled", %{empty_with_gas_params: empty_with_gas_params} do
      state = empty_with_gas_params
      current_price = state.gas_price_to_use
      eth_gap = state.gas_price_adj_params.eth_gap_without_child_blocks

      {:do_form_block, newstate} =
        state
        |> BlockQueueCore.enqueue_block(%{hash: <<0>>, number: 6 * @child_block_interval}, 1)
        |> BlockQueueCore.sync_with_ethereum(%{
          ethereum_height: 1 + eth_gap,
          mined_child_block_num: 0,
          is_empty_block: false
        })

      assert current_price < newstate.gas_price_to_use

      # assert the actual gas price based on parameters value - test could fail if params or calculation will change
      assert 200 == newstate.gas_price_to_use
    end

    @tag fixtures: [:empty_with_gas_params]
    test "does not raise the gas price above the limit", %{empty_with_gas_params: state} do
      expected_max_price = 5 * state.gas_price_to_use
      gas_params = %{state.gas_price_adj_params | gas_price_raising_factor: 10, max_gas_price: expected_max_price}

      state =
        %{state | gas_price_adj_params: gas_params}
        |> BlockQueueCore.enqueue_block(%{hash: <<0>>, number: 6 * @child_block_interval}, 1)

      # Despite Ethereum height changing multiple times, gas price does not grow since no new blocks are mined
      Enum.reduce(4..100, state, fn eth_height, state ->
        {_, state} =
          BlockQueueCore.sync_with_ethereum(state, %{
            ethereum_height: eth_height,
            mined_child_block_num: 2 * @child_block_interval,
            is_empty_block: false
          })

        assert expected_max_price == state.gas_price_to_use
        state
      end)
    end
  end

  describe "enqueue_block/3" do
    @tag fixtures: [:empty]
    test "emits a new block ASAP", %{empty: empty} do
      assert [%{hash: "2", nonce: 2}] =
               empty
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 0,
                 mined_child_block_num: 1000,
                 is_empty_block: false
               })
               |> elem(1)
               |> BlockQueueCore.enqueue_block(%{hash: "2", number: 2 * @child_block_interval}, 0)
               |> BlockQueueSubmitter.get_blocks_to_submit()
    end

    @tag fixtures: [:empty]
    test "produces child blocks that aren't repeated, if none are enqueued", %{empty: empty} do
      assert {:do_form_block, queue} =
               empty
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 2,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })

      assert {:do_not_form_block, _} =
               queue
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 3,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })
    end

    @tag fixtures: [:empty]
    test "does not enqueue block when number of enqueued block does not match expected block number", %{empty: empty} do
      {:error, :unexpected_block_number} =
        BlockQueueCore.enqueue_block(empty, %{hash: "1", number: 2 * @child_block_interval}, 0)
    end

    @tag fixtures: [:empty]
    test "produces blocks submission requests that have nonces in order", %{empty: empty} do
      assert [_, %{nonce: 2}] =
               empty
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 0,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })
               |> elem(1)
               |> BlockQueueCore.enqueue_block(%{hash: "1", number: @child_block_interval}, 0)
               |> BlockQueueCore.enqueue_block(%{hash: "2", number: 2 * @child_block_interval}, 0)
               |> BlockQueueSubmitter.get_blocks_to_submit()
    end
  end

  describe "submit_blocks/1" do
    @tag fixtures: [:empty]
    test "gets blocks to submit and submits them", %{empty: empty} do
      state =
        empty
        |> BlockQueueCore.sync_with_ethereum(%{
          ethereum_height: 0,
          mined_child_block_num: 0,
          is_empty_block: false
        })
        |> elem(1)
        |> BlockQueueCore.enqueue_block(%{hash: "success", number: @child_block_interval}, 0)
        |> BlockQueueCore.enqueue_block(%{hash: "success", number: 2 * @child_block_interval}, 0)

      assert BlockQueueCore.submit_blocks(state, FakeRootChain) == :ok
    end
  end

  # The tests below are all semi-integration tests and
  # interact with multiple modules from the BlockQueue
  # system
  describe "block queue (semi-integration)" do
    test "recovers after restart and talking to an un-synced geth" do
      # imagine restart after geth is nuked and hasn't caught up testing
      # against a disaster scenario where `BlockQueue` would start pushing
      # old blocks again
      finality_threshold = 12
      mined_blknum = 6000

      range =
        BlockQueueInitializer.child_block_nums_to_init_with(
          mined_blknum,
          9000,
          @child_block_interval,
          finality_threshold
        )

      known_hashes = ~w(1 2 3 4 5 6 7 8 9)

      {:ok, state} =
        BlockQueueCore.init(%{
          mined_child_block_num: mined_blknum,
          known_hashes: Enum.zip(range, known_hashes),
          top_mined_hash: "6",
          parent_height: 6,
          child_block_interval: @child_block_interval,
          chain_start_parent_height: 1,
          minimal_enqueue_block_gap: 1,
          finality_threshold: finality_threshold,
          last_enqueued_block_at_height: 0
        })

      assert [%{hash: "7", nonce: 7}, %{hash: "8", nonce: 8}, %{hash: "9", nonce: 9}] =
               state |> BlockQueueSubmitter.get_blocks_to_submit()

      # simulate geth catching up
      assert {:do_not_form_block, new_state} =
               BlockQueueCore.sync_with_ethereum(state, %{
                 ethereum_height: 7,
                 mined_child_block_num: 7000,
                 is_empty_block: true
               })

      assert [%{hash: "8", nonce: 8}, %{hash: "9", nonce: 9}] = new_state |> BlockQueueSubmitter.get_blocks_to_submit()
    end

    @tag fixtures: [:empty]
    test "handles interleaved Ethereum updates and enqueues", %{empty: empty} do
      # no enqueue after set_ethereum_status(1) so don't form block
      assert {:do_not_form_block, queue} =
               empty
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 1,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })
               |> elem(1)
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 2,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })
               |> elem(1)
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 3,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })

      assert {:do_form_block, queue} =
               queue
               |> BlockQueueCore.enqueue_block(%{hash: "1", number: @child_block_interval}, 0)
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 4,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })

      assert {:do_not_form_block, queue} =
               queue
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 5,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })

      assert {:do_form_block, _queue} =
               queue
               |> BlockQueueCore.enqueue_block(%{hash: "2", number: 2 * @child_block_interval}, 0)
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 6,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })
    end

    # NOTE: theoretically the back off is ver hard to get - testing if this rare occasion doesn't make the state weird
    @tag fixtures: [:empty]
    test "handle Ethereum updates backing off and jumping independently from enqueues", %{empty: empty} do
      # no enqueue after BlockQueueCore.sync_with_ethereum(2) so don't form block
      assert {:do_not_form_block, queue} =
               empty
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 1,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })
               |> elem(1)
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 2,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })
               |> elem(1)
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 1,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })

      assert {:do_form_block, queue} =
               queue
               |> BlockQueueCore.enqueue_block(%{hash: "1", number: @child_block_interval}, 0)
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 3,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })

      assert {:do_not_form_block, queue} =
               queue
               |> BlockQueueCore.enqueue_block(%{hash: "2", number: 2 * @child_block_interval}, 1)
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 2,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })

      assert {:do_form_block, _queue} =
               queue
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 4,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })
    end

    @tag fixtures: [:empty]
    test "generates blocks by last enqueued block Ethereum height and if block is empty or not", %{
      empty: empty
    } do
      %BlockQueueState{minimal_enqueue_block_gap: minimal_enqueue_block_gap, parent_height: parent_height} = empty

      assert {:do_not_form_block, _} =
               empty
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: parent_height + minimal_enqueue_block_gap,
                 mined_child_block_num: 0,
                 is_empty_block: true
               })

      assert {:do_form_block, _} =
               empty
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: parent_height + minimal_enqueue_block_gap,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })

      assert {:do_not_form_block, queue} =
               empty
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: parent_height,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })

      assert {:do_not_form_block, queue} =
               queue
               |> BlockQueueCore.enqueue_block(%{hash: "1", number: @child_block_interval}, parent_height)
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: parent_height,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })

      assert {:do_not_form_block, queue} =
               queue
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: parent_height + 1,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })

      assert {:do_not_form_block, _} =
               queue
               |> BlockQueueCore.enqueue_block(%{hash: "2", number: 2 * @child_block_interval}, parent_height + 2)
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: parent_height + 2,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })
    end

    @tag fixtures: [:empty]
    test "runs a smoke test", %{empty: empty} do
      assert {:do_not_form_block, queue} =
               empty
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 0,
                 mined_child_block_num: 0,
                 is_empty_block: false
               })
               |> elem(1)
               |> BlockQueueCore.enqueue_block(%{hash: "1", number: 1 * @child_block_interval}, 0)
               |> BlockQueueCore.enqueue_block(%{hash: "2", number: 2 * @child_block_interval}, 1)
               |> BlockQueueCore.enqueue_block(%{hash: "3", number: 3 * @child_block_interval}, 2)
               |> BlockQueueCore.enqueue_block(%{hash: "4", number: 4 * @child_block_interval}, 3)
               |> BlockQueueCore.enqueue_block(%{hash: "5", number: 5 * @child_block_interval}, 4)
               |> BlockQueueCore.sync_with_ethereum(%{
                 ethereum_height: 3,
                 mined_child_block_num: 2000,
                 is_empty_block: false
               })

      assert [%{hash: "3", nonce: 3}, %{hash: "4", nonce: 4}, %{hash: "5", nonce: 5}] =
               queue |> BlockQueueSubmitter.get_blocks_to_submit()
    end
  end

  describe "gas price adjustments (semi-integration)" do
    @tag fixtures: [:empty_with_gas_params]
    test "Gas price is lowered and then raised when ethereum blocks gap gets filled", %{
      empty_with_gas_params: empty_with_gas_params
    } do
      state =
        empty_with_gas_params |> BlockQueueCore.enqueue_block(%{hash: <<6>>, number: 6 * @child_block_interval}, 1)

      gas_params = %{state.gas_price_adj_params | eth_gap_without_child_blocks: 3}
      state1 = %{state | gas_price_adj_params: gas_params}

      {:do_form_block, state2} =
        state1
        |> BlockQueueCore.sync_with_ethereum(%{
          ethereum_height: 4,
          mined_child_block_num: 5 * @child_block_interval,
          is_empty_block: false
        })

      assert state.gas_price_to_use > state2.gas_price_to_use
      state2 = state2 |> BlockQueueCore.enqueue_block(%{hash: <<6>>, number: 7 * @child_block_interval}, 1)

      {:do_form_block, state3} =
        state2
        |> BlockQueueCore.sync_with_ethereum(%{
          ethereum_height: 6,
          mined_child_block_num: 5 * @child_block_interval,
          is_empty_block: false
        })

      assert state2.gas_price_to_use > state3.gas_price_to_use

      # Now the ethereum block gap without child blocks is reached
      {:do_form_block, state4} =
        state2
        |> BlockQueueCore.sync_with_ethereum(%{
          ethereum_height: 7,
          mined_child_block_num: 5 * @child_block_interval,
          is_empty_block: false
        })

      assert state3.gas_price_to_use < state4.gas_price_to_use
    end

    @tag fixtures: [:empty_with_gas_params]
    test "Gas price doesn't change if no new blocks are formed, and is lowered the moment there's one",
         %{empty_with_gas_params: state} do
      expected_price = state.gas_price_to_use
      current_blknum = 5 * @child_block_interval
      next_blknum = 6 * @child_block_interval

      # Despite Ethereum height changing multiple times, gas price does not grow since no new blocks are mined
      Enum.reduce(4..100, state, fn eth_height, state ->
        {_, state} =
          BlockQueueCore.sync_with_ethereum(state, %{
            ethereum_height: eth_height,
            mined_child_block_num: current_blknum,
            is_empty_block: false
          })

        assert expected_price == state.gas_price_to_use
        state
      end)

      {_, state} =
        state
        |> BlockQueueCore.enqueue_block(%{hash: <<0>>, number: next_blknum}, 1)
        |> BlockQueueCore.sync_with_ethereum(%{
          ethereum_height: 1000,
          mined_child_block_num: current_blknum,
          is_empty_block: false
        })

      assert expected_price > state.gas_price_to_use
    end
  end

  describe "submission results from Geth (semi-integration)" do
    test "everything might be ok" do
      [submission] =
        recover_state([{1000, "1"}], 0, <<0::size(256)>>) |> elem(1) |> BlockQueueSubmitter.get_blocks_to_submit()

      # no change in mined blknum
      assert :ok = BlockQueueSubmitter.process_submit_result({:ok, <<0::160>>}, submission, 1000)
      # arbitrary ignored change in mined blknum
      assert :ok = BlockQueueSubmitter.process_submit_result({:ok, <<0::160>>}, submission, 0)
      assert :ok = BlockQueueSubmitter.process_submit_result({:ok, <<0::160>>}, submission, 2000)
    end

    test "benign reports / warnings from geth" do
      [submission] =
        recover_state([{1000, "1"}], 0, <<0::size(256)>>) |> elem(1) |> BlockQueueSubmitter.get_blocks_to_submit()

      # no change in mined blknum
      assert :ok = BlockQueueSubmitter.process_submit_result(@known_transaction_response, submission, 1000)

      assert :ok = BlockQueueSubmitter.process_submit_result(@replacement_transaction_response, submission, 1000)
    end

    test "benign nonce too low error - related to our tx being mined, since the mined blknum advanced" do
      [submission] =
        recover_state([{1000, "1"}], 0, <<0::size(256)>>) |> elem(1) |> BlockQueueSubmitter.get_blocks_to_submit()

      assert :ok = BlockQueueSubmitter.process_submit_result(@nonce_too_low_response, submission, 1000)
      assert :ok = BlockQueueSubmitter.process_submit_result(@nonce_too_low_response, submission, 2000)
    end

    test "real nonce too low error" do
      [submission] =
        recover_state([{1000, "1"}], 0, <<0::size(256)>>) |> elem(1) |> BlockQueueSubmitter.get_blocks_to_submit()

      # the new mined child block number is not the one we submitted, so we expect an error an error log
      assert capture_log(fn ->
               assert {:error, :nonce_too_low} =
                        BlockQueueSubmitter.process_submit_result(@nonce_too_low_response, submission, 0)
             end) =~ "[error]"

      assert capture_log(fn ->
               assert {:error, :nonce_too_low} =
                        BlockQueueSubmitter.process_submit_result(@nonce_too_low_response, submission, 90)
             end) =~ "[error]"
    end

    test "other fatal errors" do
      [submission] =
        recover_state([{1000, "1"}], 0, <<0::size(256)>>) |> elem(1) |> BlockQueueSubmitter.get_blocks_to_submit()

      # the new mined child block number is not the one we submitted, so we expect an error an error log
      assert capture_log(fn ->
               assert {:error, :account_locked} =
                        BlockQueueSubmitter.process_submit_result(@account_locked_response, submission, 0)
             end) =~ "[error]"
    end

    @tag fixtures: [:empty_with_gas_params]
    test "gas price change only, when try to push blocks", %{empty_with_gas_params: state} do
      gas_price = state.gas_price_to_use

      state =
        Enum.reduce(4..10, state, fn eth_height, state ->
          {_, state} =
            BlockQueueCore.sync_with_ethereum(state, %{
              ethereum_height: eth_height,
              mined_child_block_num: 0,
              is_empty_block: false
            })

          assert gas_price == state.gas_price_to_use
          state
        end)

      state = state |> BlockQueueCore.enqueue_block(%{hash: <<0>>, number: 6 * @child_block_interval}, 1)

      {_, state} =
        BlockQueueCore.sync_with_ethereum(state, %{
          ethereum_height: 101,
          mined_child_block_num: 0,
          is_empty_block: false
        })

      assert state.gas_price_to_use > gas_price
    end

    @tag fixtures: [:empty_with_gas_params]
    test "gas price changes only, when etherum advanses", %{empty_with_gas_params: state} do
      gas_price = state.gas_price_to_use
      eth_height = 0

      state =
        Enum.reduce(6..20, state, fn child_number, state ->
          {_, state} =
            state
            |> BlockQueueCore.enqueue_block(%{hash: <<0>>, number: child_number * @child_block_interval}, 1)
            |> BlockQueueCore.sync_with_ethereum(%{
              ethereum_height: eth_height,
              mined_child_block_num: 0,
              is_empty_block: false
            })

          assert gas_price == state.gas_price_to_use
          state
        end)

      {_, state} =
        BlockQueueCore.sync_with_ethereum(state, %{
          ethereum_height: eth_height + 1,
          mined_child_block_num: 0,
          is_empty_block: false
        })

      assert state.gas_price_to_use < gas_price
    end

    @tag fixtures: [:empty_with_gas_params]
    test "gas price doesn't change when ethereum backs off, even if block in queue", %{empty_with_gas_params: state} do
      eth_height = 100

      {_, state} =
        BlockQueueCore.sync_with_ethereum(state, %{
          ethereum_height: eth_height,
          mined_child_block_num: 0,
          is_empty_block: false
        })

      gas_price = state.gas_price_to_use

      state
      |> BlockQueueCore.enqueue_block(%{hash: <<0>>, number: 6 * @child_block_interval}, 1)
      |> BlockQueueCore.enqueue_block(%{hash: <<0>>, number: 7 * @child_block_interval}, 1)
      |> BlockQueueCore.enqueue_block(%{hash: <<0>>, number: 8 * @child_block_interval}, 1)

      Enum.reduce(80..(eth_height - 1), state, fn eth_height, state ->
        {_, state} =
          BlockQueueCore.sync_with_ethereum(state, %{
            ethereum_height: eth_height,
            mined_child_block_num: 0,
            is_empty_block: false
          })

        assert gas_price == state.gas_price_to_use
        state
      end)
    end
  end
end
