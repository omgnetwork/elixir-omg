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

defmodule OMG.Watcher.BlockGetter.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.API.Fixtures
  use Plug.Test

  alias OMG.API
  alias OMG.API.Block
  alias OMG.API.Crypto
  alias OMG.Watcher.BlockGetter.Core
  alias OMG.Watcher.Eventer.Event

  @eth Crypto.zero_address()

  defp handle_downloaded_block(state, block) do
    assert {:ok, new_state, []} = Core.handle_downloaded_block(state, {:ok, block})
    new_state
  end

  test "get numbers of blocks to download" do
    start_block_number = 0
    interval = 1_000
    synced_height = 1
    state = Core.init(start_block_number, interval, synced_height, maximum_number_of_pending_blocks: 4)

    {state_after_chunk, block_numbers} = Core.get_numbers_of_blocks_to_download(state, 20_000)
    assert block_numbers == [1_000, 2_000, 3_000, 4_000]

    state_after_proces_down =
      state_after_chunk
      |> handle_downloaded_block(%Block{number: 4_000})
      |> handle_downloaded_block(%Block{number: 2_000})

    assert {_, [5_000, 6_000]} = Core.get_numbers_of_blocks_to_download(state_after_proces_down, 20_000)
  end

  test "first block to download number is not zero" do
    start_block_number = 7_000
    interval = 100
    synced_height = 1
    state = Core.init(start_block_number, interval, synced_height, maximum_number_of_pending_blocks: 4)
    assert {state, [7_100, 7_200, 7_300, 7_400]} = Core.get_numbers_of_blocks_to_download(state, 20_000)

    assert {:ok, _, []} =
             state
             |> handle_downloaded_block(%Block{number: 7_200})
             |> Core.handle_downloaded_block({:ok, %Block{number: 7_100}})
  end

  test "does not download same blocks twice and respects increasing next block number" do
    start_block_number = 0
    interval = 1_000
    synced_height = 1

    {state, [1_000, 2_000, 3_000]} =
      start_block_number
      |> Core.init(interval, synced_height, maximum_number_of_pending_blocks: 5)
      |> Core.get_numbers_of_blocks_to_download(4_000)

    assert {^state, []} = Core.get_numbers_of_blocks_to_download(state, 2_000)
    assert {_, [4_000, 5_000]} = Core.get_numbers_of_blocks_to_download(state, 8_000)
  end

  test "downloaded duplicated and unexpected block" do
    block_height = 0
    interval = 1_000

    {state, [1_000, 2_000]} =
      block_height
      |> Core.init(interval, maximum_number_of_pending_blocks: 5)
      |> Core.get_numbers_of_blocks_to_download(3_000)

    assert {:error, :duplicate} =
             state
             |> handle_downloaded_block(%Block{number: 2_000})
             |> Core.handle_downloaded_block({:ok, %Block{number: 2_000}})

    assert {:error, :unexpected_blok} = state |> Core.handle_downloaded_block({:ok, %Block{number: 3_000}})
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "decodes block and validates transaction execution", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state_alice_deposit
  } do
    block =
      Block.hashed_txs_at(
        [
          API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}])
        ],
        26_000
      )

    assert {:ok, state, []} = process_single_block(block)
    synced_height = 1

    assert {[{%{transactions: [tx], zero_fee_requirements: fees}, 1}], _, _, _} =
             Core.get_blocks_to_apply(state, [%{blknum: block.number, eth_height: synced_height}], synced_height)

    # check feasability of transactions from block to consume at the API.State
    assert {:ok, tx_result, _} = API.State.Core.exec(tx, fees, state_alice_deposit)

    assert {:ok, []} = Core.validate_tx_executions([{:ok, tx_result}], block)
  end

  @tag fixtures: [:alice, :bob]
  test "decodes and executes tx with different currencies, always with no fee required", %{alice: alice, bob: bob} do
    other_currency = <<1::160>>

    block =
      Block.hashed_txs_at(
        [
          API.TestHelper.create_recovered([{1, 0, 0, alice}], other_currency, [{bob, 7}, {alice, 3}]),
          API.TestHelper.create_recovered([{2, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}])
        ],
        26_000
      )

    assert {:ok, state, []} = process_single_block(block)

    synced_height = 1

    assert {[{%{transactions: [_tx1, _tx2], zero_fee_requirements: fees}, 1}], _, _, _} =
             Core.get_blocks_to_apply(state, [%{blknum: block.number, eth_height: synced_height}], synced_height)

    assert fees == %{@eth => 0, other_currency => 0}
  end

  defp process_single_block(%Block{hash: requested_hash} = block) do
    block_height = 25_000
    interval = 1_000
    synced_height = 1

    {state, _} =
      block_height
      |> Core.init(interval, synced_height)
      |> Core.get_numbers_of_blocks_to_download(block_height + 2 * interval)

    assert {:ok, decoded_block} =
             Core.validate_download_response({:ok, block}, requested_hash, block_height + interval, 0)

    Core.handle_downloaded_block(state, {:ok, decoded_block})
  end

  @tag fixtures: [:alice]
  test "does not validate block with invalid hash", %{alice: alice} do
    block_height = 0
    interval = 1_000
    synced_height = 1
    matching_bad_returned_hash = <<12::256>>

    state = Core.init(block_height, interval, synced_height)

    block = %Block{
      Block.hashed_txs_at(
        [
          API.TestHelper.create_recovered([{1_000, 20, 0, alice}], @eth, [{alice, 100}])
        ],
        1
      )
      | hash: matching_bad_returned_hash
    }

    assert {:error, :incorrect_hash, matching_bad_returned_hash, 0} ==
             Core.validate_download_response({:ok, block}, matching_bad_returned_hash, 0, 0)

    assert {{:needs_stopping, :incorrect_hash}, _,
            [%Event.InvalidBlock{error_type: :incorrect_hash, hash: ^matching_bad_returned_hash, number: 1}]} =
             Core.handle_downloaded_block(state, {:error, :incorrect_hash, matching_bad_returned_hash, 1})
  end

  @tag fixtures: [:alice]
  test "check error returned by decode_block, one of API.Core.recover_tx checks", %{alice: alice} do
    # NOTE: this test only test if API.Core.recover_tx-specific checks are run and errors returned
    #       the more extensive testing of such checks is done in API.CoreTest where it belongs

    %Block{hash: hash} =
      block =
      Block.hashed_txs_at(
        [
          API.TestHelper.create_recovered([{1_000, 20, 0, alice}], @eth, [{alice, 100}]),
          API.TestHelper.create_recovered([], @eth, [{alice, 100}])
        ],
        1
      )

    # a particular API.Core.recover_tx_error instance
    assert {:error, :no_inputs, hash, 1} == Core.validate_download_response({:ok, block}, hash, 1, 0)
  end

  test "check error returned by decode_block, hash mismatch checks" do
    hash = <<12::256>>
    block = Block.hashed_txs_at([], 1)

    assert {:error, :bad_returned_hash, hash, 1} == Core.validate_download_response({:ok, block}, hash, 1, 0)
  end

  test "check error returned by decode_block, API.Core.recover_tx checks" do
    %Block{hash: hash} = block = Block.hashed_txs_at([API.TestHelper.create_recovered([], @eth, [])], 1)

    assert {:error, :no_inputs, hash, 1} == Core.validate_download_response({:ok, block}, hash, 1, 0)
  end

  test "the blknum is overriden by the requested one" do
    %Block{hash: hash} = block = Block.hashed_txs_at([], 1)

    assert {:ok, %{number: 2 = _overriden_number}} = Core.validate_download_response({:ok, block}, hash, 2, 0)
  end

  test "got_block function called once with PotentialWithholding doesn't return BlockWithholding event" do
    block_height = 0
    synced_height = 1
    interval = 1_000

    {state, [1_000, 2_000]} =
      block_height |> Core.init(interval, synced_height) |> Core.get_numbers_of_blocks_to_download(3_000)

    potential_withholding = Core.validate_download_response({:error, :error_reason}, <<>>, 2_000, 0)

    assert {:ok, _, []} = Core.handle_downloaded_block(state, potential_withholding)
  end

  test "handle_downloaded_block function called twice with PotentialWithholding returns BlockWithholding event" do
    block_height = 0
    interval = 1_000
    synced_height = 1

    {state, [1_000, 2_000]} =
      Core.get_numbers_of_blocks_to_download(
        Core.init(
          block_height,
          interval,
          synced_height,
          maximum_number_of_pending_blocks: 5,
          maximum_block_withholding_time_ms: 0
        ),
        3_000
      )

    potential_withholding = Core.validate_download_response({:error, :error_reason}, <<>>, 2_000, 0)
    assert {:ok, state, []} = Core.handle_downloaded_block(state, potential_withholding)

    potential_withholding = Core.validate_download_response({:error, :error_reason}, <<>>, 2_000, 1)

    assert {{:needs_stopping, :withholding}, _, [%Event.BlockWithholding{blknum: 2000}]} =
             Core.handle_downloaded_block(state, potential_withholding)
  end

  test "get_numbers_of_blocks_to_download function returns number of potential withholding block which then is canceled" do
    block_height = 0
    interval = 1_000
    synced_height = 1

    {state, [1_000, 2_000, 3_000, 4_000]} =
      Core.get_numbers_of_blocks_to_download(
        Core.init(
          block_height,
          interval,
          synced_height,
          maximum_number_of_pending_blocks: 4,
          maximum_block_withholding_time_ms: 0
        ),
        20_000
      )

    state =
      state
      |> handle_downloaded_block(%Block{number: 1_000})
      |> handle_downloaded_block(%Block{number: 2_000})

    potential_withholding = Core.validate_download_response({:error, :error_reason}, <<>>, 3_000, 0)
    assert {:ok, state, []} = Core.handle_downloaded_block(state, potential_withholding)

    assert {_, [3000, 5000, 6000]} = Core.get_numbers_of_blocks_to_download(state, 20_000)

    assert {:ok, state, []} = Core.handle_downloaded_block(state, {:ok, %Block{number: 3_000}})

    assert {_, [5000, 6000, 7000, 8000]} = Core.get_numbers_of_blocks_to_download(state, 20_000)
  end

  test "get_numbers_of_blocks_to_download function doesn't return next blocks if state doesn't have empty slots left" do
    block_height = 0
    interval = 1_000
    synced_height = 1

    {state, [1_000, 2_000, 3_000]} =
      Core.get_numbers_of_blocks_to_download(
        Core.init(block_height, interval, synced_height, maximum_number_of_pending_blocks: 3),
        20_000
      )

    potential_withholding = Core.validate_download_response({:error, :error_reason}, <<>>, 1_000, 0)
    assert {:ok, state, []} = Core.handle_downloaded_block(state, potential_withholding)

    potential_withholding = Core.validate_download_response({:error, :error_reason}, <<>>, 2_000, 0)
    assert {:ok, state, []} = Core.handle_downloaded_block(state, potential_withholding)

    potential_withholding = Core.validate_download_response({:error, :error_reason}, <<>>, 3_000, 0)
    assert {:ok, state, []} = Core.handle_downloaded_block(state, potential_withholding)

    assert {_, [1000, 2000, 3000]} = Core.get_numbers_of_blocks_to_download(state, 20_000)
  end

  test "handle_downloaded_block function after maximum_block_withholding_time_ms returns BlockWithholding event" do
    block_height = 0
    interval = 1_000
    synced_height = 1

    state =
      Core.init(
        block_height,
        interval,
        synced_height,
        maximum_number_of_pending_blocks: 4,
        maximum_block_withholding_time_ms: 1000
      )

    potential_withholding = Core.validate_download_response({:error, :error_reason}, <<>>, 3_000, 0)

    assert {:ok, state, []} = Core.handle_downloaded_block(state, potential_withholding)

    potential_withholding = Core.validate_download_response({:error, :error_reason}, <<>>, 3_000, 500)

    assert {:ok, state, []} = Core.handle_downloaded_block(state, potential_withholding)

    potential_withholding = Core.validate_download_response({:error, :error_reason}, <<>>, 3_000, 1000)

    assert {{:needs_stopping, :withholding}, _state, [%Event.BlockWithholding{blknum: 3_000}]} =
             Core.handle_downloaded_block(state, potential_withholding)
  end

  test "validate_tx_executions function returns InvalidBlock event" do
    block = %Block{number: 1, hash: <<>>}

    assert {{:needs_stopping, :tx_execution},
            [
              %Event.InvalidBlock{
                error_type: :tx_execution,
                hash: "",
                number: 1
              }
            ]} = Core.validate_tx_executions([{:error, {}}], block)
  end

  test "after detecting twice same maximum possible potential withholdings get_numbers_of_blocks_to_download function still returns those blocks" do
    block_height = 0
    interval = 1_000
    synced_height = 1

    {state, [1_000, 2_000]} =
      Core.get_numbers_of_blocks_to_download(
        Core.init(
          block_height,
          interval,
          synced_height,
          maximum_number_of_pending_blocks: 2,
          maximum_block_withholding_time_ms: 10_000
        ),
        20_000
      )

    potential_withholding_1_000 = Core.validate_download_response({:error, :error_reson}, <<>>, 1_000, 0)
    potential_withholding_2_000 = Core.validate_download_response({:error, :error_reson}, <<>>, 2_000, 0)

    assert {:ok, state, []} = Core.handle_downloaded_block(state, potential_withholding_1_000)
    assert {:ok, state, []} = Core.handle_downloaded_block(state, potential_withholding_2_000)

    assert {state, [1_000, 2_000]} = Core.get_numbers_of_blocks_to_download(state, 20_000)

    assert {:ok, state, []} = Core.handle_downloaded_block(state, potential_withholding_1_000)
    assert {:ok, state, []} = Core.handle_downloaded_block(state, potential_withholding_2_000)

    assert {_state, [1_000, 2_000]} = Core.get_numbers_of_blocks_to_download(state, 20_000)
  end

  test "figures out the proper synced height on init" do
    assert 0 == Core.figure_out_exact_sync_height([], 0, 0)
    assert 0 == Core.figure_out_exact_sync_height([], 0, 10)
    assert 1 == Core.figure_out_exact_sync_height([], 1, 10)
    assert 1 == Core.figure_out_exact_sync_height([%{eth_height: 100, blknum: 9}], 1, 10)
    assert 100 == Core.figure_out_exact_sync_height([%{eth_height: 100, blknum: 10}], 1, 10)

    assert 100 ==
             [%{eth_height: 100, blknum: 10}, %{eth_height: 101, blknum: 11}, %{eth_height: 90, blknum: 9}]
             |> Core.figure_out_exact_sync_height(1, 10)
  end

  test "applying block updates height" do
    interval = 1_000

    {state, [1_000, 2_000, 3_000]} =
      0
      |> Core.init(interval, 0, maximum_number_of_pending_blocks: 5)
      |> Core.get_numbers_of_blocks_to_download(4_000)

    synced_height = 2
    next_synced_height = synced_height + 1

    state =
      state
      |> handle_downloaded_block(%Block{number: 1_000})
      |> handle_downloaded_block(%Block{number: 2_000})
      |> handle_downloaded_block(%Block{number: 3_000})

    {[{_, ^synced_height}, {_, ^synced_height}], 0, _, state} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 1_000, eth_height: synced_height}, %{blknum: 2_000, eth_height: synced_height}],
        synced_height
      )

    {state, 0, []} = Core.apply_block(state, 1_000, synced_height)

    {state, ^synced_height, [{:put, :last_block_getter_eth_height, ^synced_height}]} =
      Core.apply_block(state, 2_000, synced_height)

    {[{_, ^next_synced_height}], ^synced_height, _, state} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 3_000, eth_height: next_synced_height}],
        next_synced_height
      )

    {state, ^next_synced_height, [{:put, :last_block_getter_eth_height, ^next_synced_height}]} =
      Core.apply_block(state, 3_000, next_synced_height)

    {_, ^next_synced_height, _, _} = Core.get_blocks_to_apply(state, [], next_synced_height)
  end

  test "gets continous ranges of blocks to apply" do
    interval = 1_000

    {state, [1_000, 2_000, 3_000, 4_000]} =
      0
      |> Core.init(interval, 0, maximum_number_of_pending_blocks: 5)
      |> Core.get_numbers_of_blocks_to_download(5_000)

    state =
      state
      |> handle_downloaded_block(%Block{number: 1_000})
      |> handle_downloaded_block(%Block{number: 3_000})
      |> handle_downloaded_block(%Block{number: 4_000})

    {[{_, 1}], _, _, state} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 1_000, eth_height: 1}, %{blknum: 2_000, eth_height: 2}],
        2
      )

    state =
      state
      |> handle_downloaded_block(%Block{number: 2_000})

    {[{_, 2}], _, _, _} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 1_000, eth_height: 1}, %{blknum: 2_000, eth_height: 2}],
        2
      )
  end

  test "do not download blocks when there are too many downloaded blocks not yet applied" do
    interval = 1_000

    {state, [1_000, 2_000, 3_000]} =
      0
      |> Core.init(interval, 0, maximum_number_of_pending_blocks: 5, maximum_number_of_unapplied_blocks: 3)
      |> Core.get_numbers_of_blocks_to_download(5_000)

    {state, []} = Core.get_numbers_of_blocks_to_download(state, 5_000)

    {state, []} =
      state
      |> handle_downloaded_block(%Block{number: 1_000})
      |> Core.get_numbers_of_blocks_to_download(5_000)

    synced_height = 1

    {_, _, _, state} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 1_000, eth_height: synced_height}],
        synced_height
      )

    {_, [4_000]} = Core.get_numbers_of_blocks_to_download(state, 5_000)
  end
end
