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
  alias OMG.Watcher.Event

  @eth Crypto.zero_address()

  def assert_check(result, status, value) do
    assert {^status, new_state, ^value} = result
    new_state
  end

  def assert_check(result, value) do
    assert {new_state, ^value} = result
    new_state
  end

  defp handle_downloaded_block(state, {:ok, block}, error, events) do
    assert {^error, %{events: ^events}} = new_state = Core.handle_downloaded_block(state, {:ok, block})
    new_state
  end

  defp handle_downloaded_block(state, {:ok, block}) do
    assert {:ok, new_state} = Core.handle_downloaded_block(state, {:ok, block})
    new_state
  end

  defp handle_downloaded_block(state, block) do
    assert {:ok, new_state} = Core.handle_downloaded_block(state, {:ok, block})
    new_state
  end

  test "get numbers of blocks to download" do
    init_state(opts: [maximum_number_of_pending_blocks: 4])
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([1_000, 2_000, 3_000, 4_000])
    |> handle_downloaded_block(%Block{number: 4_000})
    |> handle_downloaded_block(%Block{number: 2_000})
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([5_000, 6_000])
  end

  test "first block to download number is not zero" do
    init_state(start_block_number: 7_000, interval: 100, opts: [maximum_number_of_pending_blocks: 4])
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([7_100, 7_200, 7_300, 7_400])
    |> handle_downloaded_block(%Block{number: 7_200})
    |> handle_downloaded_block({:ok, %Block{number: 7_100}})
  end

  test "does not download same blocks twice and respects increasing next block number" do
    init_state(opts: [maximum_number_of_pending_blocks: 5])
    |> Core.get_numbers_of_blocks_to_download(4_000)
    |> assert_check([1_000, 2_000, 3_000])
    |> Core.get_numbers_of_blocks_to_download(2_000)
    |> assert_check([])
    |> Core.get_numbers_of_blocks_to_download(8_000)
    |> assert_check([4_000, 5_000])
  end

  test "downloaded duplicated and unexpected block" do
    state =
      init_state(opts: [maximum_number_of_pending_blocks: 5])
      |> Core.get_numbers_of_blocks_to_download(3_000)
      |> assert_check([1_000, 2_000])

    assert {{:error, :duplicate}, state} =
             state
             |> handle_downloaded_block(%Block{number: 2_000})
             |> Core.handle_downloaded_block({:ok, %Block{number: 2_000}})

    assert {{:error, :unexpected_block}, _} = state |> Core.handle_downloaded_block({:ok, %Block{number: 3_000}})
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "decodes block and validates transaction execution", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state_alice_deposit
  } do
    block =
      Block.hashed_txs_at(
        [API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}])],
        26_000
      )

    state = process_single_block(block)
    synced_height = 2

    assert {[{%{transactions: [tx], zero_fee_requirements: fees}, 2}], _, _, _} =
             Core.get_blocks_to_apply(state, [%{blknum: block.number, eth_height: synced_height}], synced_height)

    # check feasibility of transactions from block to consume at the API.State
    assert {:ok, tx_result, _} = API.State.Core.exec(state_alice_deposit, tx, fees)

    assert {:ok, ^state} = Core.validate_executions([{:ok, tx_result}], {:ok, []}, block, state)

    assert {:ok, []} = Core.chain_ok(state)

    assert {{:error, :unchallenged_exit, []}, state} =
             Core.validate_executions([{:ok, tx_result}], {{:error, :unchallenged_exit}, []}, block, state)

    assert {:error, []} = Core.chain_ok(state)
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

    state = process_single_block(block)

    synced_height = 2

    assert {[{%{transactions: [_tx1, _tx2], zero_fee_requirements: fees}, _}], _, _, _} =
             Core.get_blocks_to_apply(state, [%{blknum: block.number, eth_height: synced_height}], synced_height)

    assert fees == %{@eth => 0, other_currency => 0}
  end

  defp process_single_block(%Block{hash: requested_hash} = block) do
    block_height = 25_000
    interval = 1_000

    {state, _} =
      init_state(start_block_number: block_height, interval: interval)
      |> Core.get_numbers_of_blocks_to_download(block_height + 2 * interval)

    assert {:ok, decoded_block} =
             Core.validate_download_response({:ok, block}, requested_hash, block_height + interval, 0, 0)

    handle_downloaded_block(state, decoded_block)
  end

  @tag fixtures: [:alice]
  test "does not validate block with invalid hash", %{alice: alice} do
    matching_bad_returned_hash = <<12::256>>
    state = init_state()

    block = %Block{
      Block.hashed_txs_at(
        [API.TestHelper.create_recovered([{1_000, 20, 0, alice}], @eth, [{alice, 100}])],
        1
      )
      | hash: matching_bad_returned_hash
    }

    assert {:error, :incorrect_hash, matching_bad_returned_hash, 0} ==
             Core.validate_download_response({:ok, block}, matching_bad_returned_hash, 0, 0, 0)

    events = [%Event.InvalidBlock{error_type: :incorrect_hash, hash: matching_bad_returned_hash, blknum: 1}]

    assert {{:error, :incorrect_hash}, %{events: ^events}} =
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
    assert {:error, :no_inputs, hash, 1} == Core.validate_download_response({:ok, block}, hash, 1, 0, 0)
  end

  test "check error returned by decode_block, hash mismatch checks" do
    hash = <<12::256>>
    block = Block.hashed_txs_at([], 1)

    assert {:error, :bad_returned_hash, hash, 1} == Core.validate_download_response({:ok, block}, hash, 1, 0, 0)
  end

  test "check error returned by decode_block, API.Core.recover_tx checks" do
    %Block{hash: hash} = block = Block.hashed_txs_at([API.TestHelper.create_recovered([], @eth, [])], 1)

    assert {:error, :no_inputs, hash, 1} == Core.validate_download_response({:ok, block}, hash, 1, 0, 0)
  end

  test "the blknum is overriden by the requested one" do
    %Block{hash: hash} = block = Block.hashed_txs_at([], 1)

    assert {:ok, %{number: 2 = _overridden_number}} = Core.validate_download_response({:ok, block}, hash, 2, 0, 0)
  end

  test "handle_downloaded_block function called once with PotentialWithholdingReport doesn't return BlockWithholding event, and get_numbers_of_blocks_to_download function returns this block" do
    {:ok, %Core.PotentialWithholdingReport{}} =
      potential_withholding = Core.validate_download_response({:error, :error_reason}, <<>>, 2_000, 0, 0)

    init_state()
    |> Core.get_numbers_of_blocks_to_download(3_000)
    |> assert_check([1_000, 2_000])
    |> handle_downloaded_block(potential_withholding)
    |> Core.get_numbers_of_blocks_to_download(3_000)
    |> assert_check([2_000])
  end

  test "handle_downloaded_block function called twice with PotentialWithholdingReport returns BlockWithholding event" do
    requested_hash = <<1>>

    init_state(opts: [maximum_number_of_pending_blocks: 5, maximum_block_withholding_time_ms: 0])
    |> Core.get_numbers_of_blocks_to_download(3_000)
    |> assert_check([1_000, 2_000])
    |> handle_downloaded_block(Core.validate_download_response({:error, :error_reason}, requested_hash, 2_000, 0, 0))
    |> handle_downloaded_block(
      Core.validate_download_response({:error, :error_reason}, requested_hash, 2_000, 0, 1),
      {:error, :withholding},
      [%Event.BlockWithholding{blknum: 2000, hash: requested_hash}]
    )
  end

  test "get_numbers_of_blocks_to_download function returns number of potential withholding block which then is canceled" do
    init_state(opts: [maximum_number_of_pending_blocks: 4, maximum_block_withholding_time_ms: 0])
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([1_000, 2_000, 3_000, 4_000])
    |> handle_downloaded_block(%Block{number: 1_000})
    |> handle_downloaded_block(%Block{number: 2_000})
    |> handle_downloaded_block(Core.validate_download_response({:error, :error_reason}, <<>>, 3_000, 0, 0))
    |> Core.get_numbers_of_blocks_to_download(5_000)
    |> assert_check([3_000])
    |> handle_downloaded_block(%Block{number: 3_000})
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([5_000, 6_000, 7_000])
  end

  test "get_numbers_of_blocks_to_download does not return blocks that are being downloaded" do
    init_state(opts: [maximum_number_of_pending_blocks: 4, maximum_block_withholding_time_ms: 0])
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([1_000, 2_000, 3_000, 4_000])
    |> handle_downloaded_block(%Block{number: 1_000})
    |> handle_downloaded_block(%Block{number: 2_000})
    |> handle_downloaded_block(Core.validate_download_response({:error, :error_reason}, <<>>, 3_000, 0, 0))
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([3_000, 5_000, 6_000])
    |> handle_downloaded_block(%Block{number: 5_000})
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([7_000])
  end

  test "get_numbers_of_blocks_to_download function doesn't return next blocks if state doesn't have empty slots left" do
    init_state(opts: [maximum_number_of_pending_blocks: 3])
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([1_000, 2_000, 3_000])
    |> handle_downloaded_block(Core.validate_download_response({:error, :error_reason}, <<>>, 1_000, 0, 0))
    |> handle_downloaded_block(Core.validate_download_response({:error, :error_reason}, <<>>, 2_000, 0, 0))
    |> handle_downloaded_block(Core.validate_download_response({:error, :error_reason}, <<>>, 3_000, 0, 0))
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([1_000, 2_000, 3_000])
  end

  test "handle_downloaded_block function after maximum_block_withholding_time_ms returns BlockWithholding event" do
    requested_hash = <<1>>

    init_state(opts: [maximum_number_of_pending_blocks: 4, maximum_block_withholding_time_ms: 1000])
    |> handle_downloaded_block(Core.validate_download_response({:error, :error_reason}, requested_hash, 3_000, 0, 0))
    |> handle_downloaded_block(Core.validate_download_response({:error, :error_reason}, requested_hash, 3_000, 0, 500))
    |> handle_downloaded_block(
      Core.validate_download_response({:error, :error_reason}, requested_hash, 3_000, 0, 1000),
      {:error, :withholding},
      [%Event.BlockWithholding{blknum: 3_000, hash: requested_hash}]
    )
  end

  test "validate_executions function prevent getter from progressing when unchallenged_exit is detected" do
    state = init_state()

    block = %Block{number: 1, hash: <<>>}

    assert {{:error, :unchallenged_exit, []}, state} =
             Core.validate_executions([], {{:error, :unchallenged_exit}, []}, block, state)

    assert {:error, []} = Core.chain_ok(state)
  end

  test "validate_executions function prevent getter from progressing when invalid block is detected" do
    state = init_state()

    block = %Block{number: 1, hash: <<>>}

    assert {{:error, :tx_execution, {}}, state} = Core.validate_executions([{:error, {}}], {:ok, []}, block, state)

    assert {:error, [%Event.InvalidBlock{error_type: :tx_execution, hash: "", blknum: 1}]} = Core.chain_ok(state)
  end

  test "after detecting twice same maximum possible potential withholdings get_numbers_of_blocks_to_download don't return this block" do
    potential_withholding_1_000 = Core.validate_download_response({:error, :error_reson}, <<>>, 1_000, 0, 0)
    potential_withholding_2_000 = Core.validate_download_response({:error, :error_reson}, <<>>, 2_000, 0, 0)

    init_state(opts: [maximum_number_of_pending_blocks: 2, maximum_block_withholding_time_ms: 10_000])
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([1_000, 2_000])
    |> handle_downloaded_block(potential_withholding_1_000)
    |> handle_downloaded_block(potential_withholding_2_000)
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([1_000, 2_000])
    |> handle_downloaded_block(potential_withholding_2_000)
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([2_000])
    |> handle_downloaded_block(potential_withholding_1_000)
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([1_000])
  end

  @tag :capture_log
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

  @tag :capture_log
  test "figures out the proper synced height on init, if there's many submissions per eth height" do
    # the exact sync height is picked only if it's the youngest submission, otherwise backoff
    assert 1 == Core.figure_out_exact_sync_height([%{eth_height: 100, blknum: 9}, %{eth_height: 100, blknum: 8}], 1, 10)

    assert 99 ==
             Core.figure_out_exact_sync_height([%{eth_height: 100, blknum: 10}, %{eth_height: 100, blknum: 11}], 1, 10)

    assert 100 ==
             Core.figure_out_exact_sync_height([%{eth_height: 100, blknum: 10}, %{eth_height: 100, blknum: 9}], 1, 10)

    assert 100 ==
             Core.figure_out_exact_sync_height(
               [%{eth_height: 100, blknum: 10}, %{eth_height: 101, blknum: 11}, %{eth_height: 100, blknum: 9}],
               1,
               10
             )

    assert 99 ==
             Core.figure_out_exact_sync_height(
               [%{eth_height: 100, blknum: 10}, %{eth_height: 101, blknum: 11}, %{eth_height: 100, blknum: 11}],
               1,
               10
             )
  end

  test "applying block updates height" do
    state =
      init_state(synced_height: 0, opts: [maximum_number_of_pending_blocks: 5])
      |> Core.get_numbers_of_blocks_to_download(4_000)
      |> assert_check([1_000, 2_000, 3_000])
      |> handle_downloaded_block(%Block{number: 1_000})
      |> handle_downloaded_block(%Block{number: 2_000})
      |> handle_downloaded_block(%Block{number: 3_000})

    synced_height = 2
    next_synced_height = synced_height + 1

    assert {[{_, ^synced_height}, {_, ^synced_height}], 0, [], state} =
             Core.get_blocks_to_apply(
               state,
               [%{blknum: 1_000, eth_height: synced_height}, %{blknum: 2_000, eth_height: synced_height}],
               synced_height
             )

    assert {state, 0, []} = Core.apply_block(state, 1_000)

    assert {state, ^synced_height, [{:put, :last_block_getter_eth_height, ^synced_height}]} =
             Core.apply_block(state, 2_000)

    assert {[{_, ^next_synced_height}], ^synced_height, [], state} =
             Core.get_blocks_to_apply(
               state,
               [%{blknum: 3_000, eth_height: next_synced_height}],
               next_synced_height
             )

    assert {state, ^next_synced_height, [{:put, :last_block_getter_eth_height, ^next_synced_height}]} =
             Core.apply_block(state, 3_000)

    # weird case when submissions for next_synced_height are now empty
    assert {[], ^next_synced_height, [], ^state} = Core.get_blocks_to_apply(state, [], next_synced_height)

    # moving forward
    next_synced_height2 = next_synced_height + 1

    assert {[], ^next_synced_height2, [{:put, :last_block_getter_eth_height, ^next_synced_height2}], _} =
             Core.get_blocks_to_apply(state, [], next_synced_height2)
  end

  test "long running applying block scenario" do
    # this test replicates a long running scenario, with various inputs from the root chain coordinator
    # We're testing if we're applying blocks and height updates correctly

    # child block submissions on the root chain, by eth_height
    submissions = %{
      57 => [%{blknum: 0, eth_height: 57}],
      58 => [%{blknum: 1000, eth_height: 58}],
      59 => [%{blknum: 2000, eth_height: 59}],
      60 => [%{blknum: 3000, eth_height: 60}],
      61 => [%{blknum: 4000, eth_height: 61}, %{blknum: 5000, eth_height: 61}],
      62 => [],
      63 => [%{blknum: 6000, eth_height: 63}, %{blknum: 7000, eth_height: 63}],
      64 => []
    }

    # take a flattened list of submissions between two heights (inclusive, just like Eth events API works)
    take_submissions = fn {first, last} ->
      Map.take(submissions, Range.new(first, last)) |> Enum.flat_map(fn {_k, v} -> v end)
    end

    state =
      init_state(synced_height: 58, start_block_number: 1_000, opts: [maximum_number_of_pending_blocks: 3])
      |> Core.get_numbers_of_blocks_to_download(16_000_000)
      |> assert_check([2_000, 3_000, 4_000])
      |> handle_downloaded_block(%Block{number: 2_000})
      |> handle_downloaded_block(%Block{number: 3_000})
      |> handle_downloaded_block(%Block{number: 4_000})

    # coordinator dwells in the past
    assert {[], 58, [], _} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.({58, 58}),
               58
             )

    # coordinator allows into the future
    assert {[{%{number: 2_000}, 59}, {%{number: 3_000}, 60}], 58, [], state_alt} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 60)),
               60
             )

    assert {_, 59, [{:put, :last_block_getter_eth_height, 59}]} = Core.apply_block(state_alt, 2_000)
    assert {_, 60, [{:put, :last_block_getter_eth_height, 60}]} = Core.apply_block(state_alt, 3_000)

    # coordinator on time
    assert {[{%{number: 2_000}, 59}], 58, [], state} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 59)),
               59
             )

    assert {state, 59, [{:put, :last_block_getter_eth_height, 59}]} = Core.apply_block(state, 2_000)

    state =
      state
      |> Core.get_numbers_of_blocks_to_download(16_000_000)
      |> assert_check([5_000, 6_000, 7_000])
      |> handle_downloaded_block(%Block{number: 5_000})
      |> handle_downloaded_block(%Block{number: 6_000})

    # coordinator dwells in the past
    assert {[], 59, [], ^state} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.({59, 59}),
               59
             )

    # coordinator allows into the future
    assert {[{%{number: 3_000}, 60}, {%{number: 4_000}, 61}, {%{number: 5_000}, 61}], 59, [], state_alt} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 61)),
               61
             )

    assert {state_alt, 60, [{:put, :last_block_getter_eth_height, 60}]} = Core.apply_block(state_alt, 3_000)
    assert {state_alt, 60, []} = Core.apply_block(state_alt, 4_000)
    assert {_, 61, [{:put, :last_block_getter_eth_height, 61}]} = Core.apply_block(state_alt, 5_000)

    # coordinator on time
    assert {[{%{number: 3_000}, 60}], 59, [], state} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 60)),
               60
             )

    assert {state, 60, [{:put, :last_block_getter_eth_height, 60}]} = Core.apply_block(state, 3_000)

    # coordinator dwells in the past
    assert {[], 60, [], ^state} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.({60, 60}),
               60
             )

    # coordinator allows into the future
    assert {[{%{number: 4_000}, 61}, {%{number: 5_000}, 61}], 60, [], state_alt} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 62)),
               62
             )

    assert {state_alt, 60, []} = Core.apply_block(state_alt, 4_000)
    assert {_, 61, [{:put, :last_block_getter_eth_height, 61}]} = Core.apply_block(state_alt, 5_000)

    # coordinator on time
    assert {[{%{number: 4_000}, 61}, {%{number: 5_000}, 61}], 60, [], state} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 61)),
               61
             )

    assert {state, 60, []} = Core.apply_block(state, 4_000)
    assert {state, 61, [{:put, :last_block_getter_eth_height, 61}]} = Core.apply_block(state, 5_000)

    # coordinator dwells in the past
    assert {[], 61, [], ^state} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.({61, 61}),
               61
             )

    # coordinator allows into the future
    assert {[{%{number: 6_000}, 63}], 61, [], state_alt} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 63)),
               63
             )

    assert {state_alt, 61, []} = Core.apply_block(state_alt, 6_000)
    assert {_, 63, [{:put, :last_block_getter_eth_height, 63}]} = Core.apply_block(state_alt, 7_000)

    # coordinator on time
    assert {[], 62, [{:put, :last_block_getter_eth_height, 62}], state} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 62)),
               62
             )

    # coordinator dwells in the past
    assert {[], 62, [], ^state} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 62)),
               62
             )

    # coordinator allows into the future
    assert {[{%{number: 6_000}, 63}], 62, [], state_alt} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 64)),
               64
             )

    assert {_, 62, []} = Core.apply_block(state_alt, 6_000)

    # coordinator on time
    assert {[{%{number: 6_000}, 63}], 62, [], state} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 63)),
               63
             )

    assert {_, 62, []} = Core.apply_block(state, 6_000)
  end

  test "gets continous ranges of blocks to apply" do
    state =
      init_state(synced_height: 0, opts: [maximum_number_of_pending_blocks: 5])
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([1_000, 2_000, 3_000, 4_000])
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
    state =
      init_state(synced_height: 0, opts: [maximum_number_of_pending_blocks: 5, maximum_number_of_unapplied_blocks: 3])
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([1_000, 2_000, 3_000])
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([])
      |> handle_downloaded_block(%Block{number: 1_000})
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([])

    synced_height = 1

    {_, _, _, state} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 1_000, eth_height: synced_height}],
        synced_height
      )

    {_, [4_000]} = Core.get_numbers_of_blocks_to_download(state, 5_000)
  end

  test "when State is not at the beginning should not init state properly" do
    start_block_number = 0
    interval = 1_000
    synced_height = 1
    block_reorg_margin = 5
    state_at_beginning = false
    last_persisted_block = nil

    assert Core.init(
             start_block_number,
             interval,
             synced_height,
             block_reorg_margin,
             last_persisted_block,
             state_at_beginning
           ) == {:error, :not_at_block_beginning}
  end

  test "maximum_number_of_pending_blocks can't be too low" do
    start_block_number = 0
    interval = 1_000
    synced_height = 1
    block_reorg_margin = 5
    state_at_beginning = true
    last_persisted_block = nil

    assert Core.init(
             start_block_number,
             interval,
             synced_height,
             block_reorg_margin,
             last_persisted_block,
             state_at_beginning,
             maximum_number_of_pending_blocks: 0
           ) == {:error, :maximum_number_of_pending_blocks_too_low}
  end

  test "BlockGetter omits submissions of already applied blocks" do
    state =
      init_state(synced_height: 1, start_block_number: 1000)
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([2_000, 3_000, 4_000])
      |> handle_downloaded_block(%Block{number: 2_000})

    {[{%Block{number: 2_000}, 2}], 1, _, _} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 1_000, eth_height: 1}, %{blknum: 2_000, eth_height: 2}],
        2
      )
  end

  test "an unapplied block appears in an already synced eth block (due to reorg)" do
    state =
      init_state(synced_height: 2, start_block_number: 1000)
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([2_000, 3_000, 4_000])
      |> handle_downloaded_block(%Block{number: 2_000})
      |> handle_downloaded_block(%Block{number: 3_000})

    {[{%Block{number: 2_000}, 1}, {%Block{number: 3_000}, 3}], 2, _, _} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 2_000, eth_height: 1}, %{blknum: 3_000, eth_height: 3}],
        3
      )
  end

  test "an already applied child chain block appears in a block above synced_height (due to a reorg)" do
    state =
      init_state(start_block_number: 1_000)
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([2_000, 3_000, 4_000])
      |> handle_downloaded_block(%Block{number: 2_000})

    {[{%Block{number: 2_000}, 3}], 1, [], _} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 1_000, eth_height: 3}, %{blknum: 2_000, eth_height: 3}],
        3
      )
  end

  test "apply block with eth_height lower than synced_height" do
    state =
      init_state(synced_height: 2)
      |> Core.get_numbers_of_blocks_to_download(2_000)
      |> assert_check([1_000])
      |> handle_downloaded_block(%Block{number: 1_000})

    {[{%Block{number: 1_000}, 1}], 2, [], state} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 1_000, eth_height: 1}],
        3
      )

    {_, 2, _} = Core.apply_block(state, 1_000)
  end

  test "apply a block that moved forward" do
    state =
      init_state(synced_height: 1, start_block_number: 1000)
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([2_000, 3_000, 4_000])

    # block 2_000 first appears at height 3
    {[], 1, [], state} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 2_000, eth_height: 3}, %{blknum: 3_000, eth_height: 4}],
        4
      )

    # download blocks
    state =
      state
      |> handle_downloaded_block(%Block{number: 2_000})
      |> handle_downloaded_block(%Block{number: 3_000})

    # block then moves forward
    {[{%Block{number: 2_000}, 4}, {%Block{number: 3_000}, 4}], 1, [], state} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 2_000, eth_height: 4}, %{blknum: 3_000, eth_height: 4}],
        4
      )

    # the block is applied at height it was first seen
    {state, 3, _} = Core.apply_block(state, 2_000)
    {_, 4, _} = Core.apply_block(state, 3_000)
  end

  test "apply a block that moved backward" do
    state =
      init_state(synced_height: 1, start_block_number: 1000)
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([2_000, 3_000, 4_000])

    # block 2_000 first appears at height 3
    {[], 1, [], state} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 2_000, eth_height: 3}, %{blknum: 3_000, eth_height: 4}],
        4
      )

    # download blocks
    state =
      state
      |> handle_downloaded_block(%Block{number: 2_000})
      |> handle_downloaded_block(%Block{number: 3_000})

    # block then moves backward
    {[{%Block{number: 2_000}, 2}, {%Block{number: 3_000}, 4}], 1, [], state} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 2_000, eth_height: 2}, %{blknum: 3_000, eth_height: 4}],
        4
      )

    # the block is applied at updated height
    {state, 2, _} = Core.apply_block(state, 2_000)
    {_, 4, _} = Core.apply_block(state, 3_000)
  end

  test "move forward even though an applied block appears in submissions" do
    state =
      init_state(start_block_number: 1_000, synced_height: 2)
      |> Core.get_numbers_of_blocks_to_download(3_000)
      |> assert_check([2_000])

    {[], 3, [_], _} =
      Core.get_blocks_to_apply(
        state,
        [%{blknum: 1_000, eth_height: 1}],
        3
      )
  end

  test "returns valid eth range" do
    # properly looks `block_reorg_margin` number of blocks backward
    state = init_state(synced_height: 100, block_reorg_margin: 10)
    assert {100 - 10, 101} == Core.get_eth_range_for_block_submitted_events(state, 101)

    # beginning of the range is no less than 0
    state = init_state(synced_height: 0, block_reorg_margin: 10)
    assert {0, 101} == Core.get_eth_range_for_block_submitted_events(state, 101)
  end

  defp init_state(opts \\ []) do
    defaults = [
      start_block_number: 0,
      interval: 1_000,
      synced_height: 1,
      block_reorg_margin: 5,
      state_at_beginning: true,
      opts: []
    ]

    %{
      start_block_number: start_block_number,
      interval: interval,
      synced_height: synced_height,
      block_reorg_margin: block_reorg_margin,
      state_at_beginning: state_at_beginning,
      opts: opts
    } = defaults |> Keyword.merge(opts) |> Map.new()

    {:ok, state} =
      Core.init(start_block_number, interval, synced_height, block_reorg_margin, nil, state_at_beginning, opts)

    state
  end

  describe "WatcherDB idempotency:" do
    test "prevents older or block with the same blknum as previously consumed" do
      last_persisted_block = 3000

      assert [] == Core.ensure_block_imported_once(%Block{number: 2000}, 1, last_persisted_block)
      assert [] == Core.ensure_block_imported_once(%Block{number: last_persisted_block}, 1, last_persisted_block)
    end

    test "allows newer blocks to get consumed" do
      last_persisted_block = 3000

      assert [
               %{
                 eth_height: 1,
                 blknum: 4000,
                 blkhash: <<0::256>>,
                 timestamp: 0,
                 transactions: []
               }
             ] ==
               Core.ensure_block_imported_once(
                 %{number: 4000, transactions: [], hash: <<0::256>>, timestamp: 0},
                 1,
                 last_persisted_block
               )
    end

    test "do not hold blocks when not properly initialized or DB empty" do
      assert [
               %{
                 eth_height: 1,
                 blknum: 4000,
                 blkhash: <<0::256>>,
                 timestamp: 0,
                 transactions: []
               }
             ] ==
               Core.ensure_block_imported_once(
                 %{number: 4000, transactions: [], hash: <<0::256>>, timestamp: 0},
                 1,
                 nil
               )
    end
  end
end
