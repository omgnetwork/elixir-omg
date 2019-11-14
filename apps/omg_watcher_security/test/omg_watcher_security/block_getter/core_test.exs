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

defmodule OMG.WatcherSecurity.BlockGetter.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.Fixtures
  use Plug.Test

  alias OMG.Block
  alias OMG.WatcherSecurity.BlockGetter.BlockApplication
  alias OMG.WatcherSecurity.BlockGetter.Core
  alias OMG.WatcherSecurity.Event

  @eth OMG.Eth.RootChain.eth_pseudo_address()

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
    init_state(init_opts: [maximum_number_of_pending_blocks: 4])
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([1_000, 2_000, 3_000, 4_000])
    |> handle_downloaded_block(%BlockApplication{number: 4_000})
    |> handle_downloaded_block(%BlockApplication{number: 2_000})
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([5_000, 6_000])
  end

  test "first block to download number is not zero" do
    init_state(start_block_number: 7_000, interval: 100, init_opts: [maximum_number_of_pending_blocks: 4])
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([7_100, 7_200, 7_300, 7_400])
    |> handle_downloaded_block(%BlockApplication{number: 7_200})
    |> handle_downloaded_block({:ok, %BlockApplication{number: 7_100}})
  end

  test "does not download same blocks twice and respects increasing next block number" do
    init_state(init_opts: [maximum_number_of_pending_blocks: 5])
    |> Core.get_numbers_of_blocks_to_download(4_000)
    |> assert_check([1_000, 2_000, 3_000])
    |> Core.get_numbers_of_blocks_to_download(2_000)
    |> assert_check([])
    |> Core.get_numbers_of_blocks_to_download(8_000)
    |> assert_check([4_000, 5_000])
  end

  test "downloaded duplicated and unexpected block" do
    state =
      init_state(init_opts: [maximum_number_of_pending_blocks: 5])
      |> Core.get_numbers_of_blocks_to_download(3_000)
      |> assert_check([1_000, 2_000])

    assert {{:error, :duplicate}, state} =
             state
             |> handle_downloaded_block(%BlockApplication{number: 2_000})
             |> Core.handle_downloaded_block({:ok, %BlockApplication{number: 2_000}})

    assert {{:error, :unexpected_block}, _} =
             state |> Core.handle_downloaded_block({:ok, %BlockApplication{number: 3_000}})
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "decodes block and validates transaction execution", %{
    alice: alice,
    bob: bob,
    state_alice_deposit: state_alice_deposit
  } do
    block =
      [OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}])]
      |> Block.hashed_txs_at(26_000)

    state = process_single_block(block)
    synced_height = 2

    assert {[
              %BlockApplication{
                transactions: [tx],
                eth_height: ^synced_height,
                eth_height_done: true
              }
            ], _, _,
            _} = Core.get_blocks_to_apply(state, [%{blknum: block.number, eth_height: synced_height}], synced_height)

    # check feasibility of transactions from block to consume at the OMG.State
    assert {:ok, tx_result, _} = OMG.State.Core.exec(state_alice_deposit, tx, :no_fees_required)

    assert {:ok, ^state} = Core.validate_executions([{:ok, tx_result}], block, state)

    assert {:ok, []} = Core.chain_ok(state)
  end

  @tag fixtures: [:alice, :bob]
  test "decodes and executes tx with different currencies, always with no fee required", %{alice: alice, bob: bob} do
    other_currency = <<1::160>>

    block =
      [
        OMG.TestHelper.create_recovered([{1, 0, 0, alice}], other_currency, [{bob, 7}, {alice, 3}]),
        OMG.TestHelper.create_recovered([{2, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}])
      ]
      |> Block.hashed_txs_at(26_000)

    state = process_single_block(block)

    synced_height = 2

    assert {[%BlockApplication{transactions: [_tx1, _tx2]}], _, _, _} =
             Core.get_blocks_to_apply(state, [%{blknum: block.number, eth_height: synced_height}], synced_height)
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
      Block.hashed_txs_at([OMG.TestHelper.create_recovered([{1_000, 20, 0, alice}], @eth, [{alice, 100}])], 1)
      | hash: matching_bad_returned_hash
    }

    assert {:error, {:incorrect_hash, matching_bad_returned_hash, 1}} ==
             Core.validate_download_response({:ok, block}, matching_bad_returned_hash, 1, 0, 0)

    events = [%Event.InvalidBlock{error_type: :incorrect_hash, hash: matching_bad_returned_hash, blknum: 1}]

    assert {{:error, :incorrect_hash}, %{events: ^events}} =
             Core.handle_downloaded_block(state, {:error, {:incorrect_hash, matching_bad_returned_hash, 1}})
  end

  @tag fixtures: [:alice]
  test "check error returned by decoding, one of Transaction.Recovered.recover_from checks", %{alice: alice} do
    # NOTE: this test only test if Transaction.Recovered.recover_from-specific checks are run and errors returned
    #       the more extensive testing of such checks is done in API.CoreTest where it belongs

    %Block{hash: hash} =
      block =
      [OMG.TestHelper.create_recovered([{1_000, 20, 0, alice}], @eth, [{alice, 100}])]
      |> Block.hashed_txs_at(1)

    block = %{block | transactions: block.transactions ++ [<<34>>]}

    # a particular Transaction.Recovered.recover_from error instance
    assert {:error, {:malformed_transaction, hash, 1}} == Core.validate_download_response({:ok, block}, hash, 1, 0, 0)
  end

  test "check error returned by decode_block, hash mismatch checks" do
    hash = <<12::256>>
    block = Block.hashed_txs_at([], 1)

    assert {:error, {:bad_returned_hash, hash, 1}} == Core.validate_download_response({:ok, block}, hash, 1, 0, 0)
  end

  test "the blknum is checked against the requested one" do
    %Block{hash: hash} = block = Block.hashed_txs_at([], 1)
    assert {:error, {:bad_returned_number, ^hash, 2}} = Core.validate_download_response({:ok, block}, hash, 2, 0, 0)
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

    init_state(init_opts: [maximum_number_of_pending_blocks: 5, maximum_block_withholding_time_ms: 0])
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
    init_state(init_opts: [maximum_number_of_pending_blocks: 4, maximum_block_withholding_time_ms: 0])
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([1_000, 2_000, 3_000, 4_000])
    |> handle_downloaded_block(%BlockApplication{number: 1_000})
    |> handle_downloaded_block(%BlockApplication{number: 2_000})
    |> handle_downloaded_block(Core.validate_download_response({:error, :error_reason}, <<>>, 3_000, 0, 0))
    |> Core.get_numbers_of_blocks_to_download(5_000)
    |> assert_check([3_000])
    |> handle_downloaded_block(%BlockApplication{number: 3_000})
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([5_000, 6_000, 7_000])
  end

  test "get_numbers_of_blocks_to_download does not return blocks that are being downloaded" do
    init_state(init_opts: [maximum_number_of_pending_blocks: 4, maximum_block_withholding_time_ms: 0])
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([1_000, 2_000, 3_000, 4_000])
    |> handle_downloaded_block(%BlockApplication{number: 1_000})
    |> handle_downloaded_block(%BlockApplication{number: 2_000})
    |> handle_downloaded_block(Core.validate_download_response({:error, :error_reason}, <<>>, 3_000, 0, 0))
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([3_000, 5_000, 6_000])
    |> handle_downloaded_block(%BlockApplication{number: 5_000})
    |> Core.get_numbers_of_blocks_to_download(20_000)
    |> assert_check([7_000])
  end

  test "get_numbers_of_blocks_to_download function doesn't return next blocks if state doesn't have empty slots left" do
    init_state(init_opts: [maximum_number_of_pending_blocks: 3])
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

    init_state(init_opts: [maximum_number_of_pending_blocks: 4, maximum_block_withholding_time_ms: 1000])
    |> handle_downloaded_block(Core.validate_download_response({:error, :error_reason}, requested_hash, 3_000, 0, 0))
    |> handle_downloaded_block(Core.validate_download_response({:error, :error_reason}, requested_hash, 3_000, 0, 500))
    |> handle_downloaded_block(
      Core.validate_download_response({:error, :error_reason}, requested_hash, 3_000, 0, 1000),
      {:error, :withholding},
      [%Event.BlockWithholding{blknum: 3_000, hash: requested_hash}]
    )
  end

  test "allows progressing when no unchallenged exits are detected" do
    assert {:ok, []} = init_state() |> Core.consider_exits({:ok, []}) |> Core.chain_ok()
    assert {:ok, []} = init_state() |> Core.consider_exits({:ok, [%Event.InvalidExit{}]}) |> Core.chain_ok()
  end

  @tag :capture_log
  test "prevents progressing when unchallenged_exit is detected" do
    assert {:error, []} = init_state() |> Core.consider_exits({{:error, :unchallenged_exit}, []}) |> Core.chain_ok()
  end

  @tag :capture_log
  test "prevents applying when started with an unchallenged_exit" do
    state = init_state(exit_processor_results: {{:error, :unchallenged_exit}, []})
    assert {:error, []} = Core.chain_ok(state)
  end

  test "validate_executions function prevent getter from progressing when invalid block is detected" do
    state = init_state()
    block = %Block{number: 1, hash: <<>>}

    assert {{:error, {:tx_execution, :some_exec_error_reason}}, state} =
             Core.validate_executions([{:error, :some_exec_error_reason}], block, state)

    assert {:error, [%Event.InvalidBlock{error_type: :tx_execution, hash: "", blknum: 1}]} = Core.chain_ok(state)
  end

  test "after detecting twice same maximum possible potential withholdings get_numbers_of_blocks_to_download don't return this block" do
    potential_withholding_1_000 = Core.validate_download_response({:error, :error_reson}, <<>>, 1_000, 0, 0)
    potential_withholding_2_000 = Core.validate_download_response({:error, :error_reson}, <<>>, 2_000, 0, 0)

    init_state(init_opts: [maximum_number_of_pending_blocks: 2, maximum_block_withholding_time_ms: 10_000])
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

  test "applying block updates height" do
    state =
      init_state(synced_height: 0, init_opts: [maximum_number_of_pending_blocks: 5])
      |> Core.get_numbers_of_blocks_to_download(4_000)
      |> assert_check([1_000, 2_000, 3_000])
      |> handle_downloaded_block(%BlockApplication{number: 1_000})
      |> handle_downloaded_block(%BlockApplication{number: 2_000})
      |> handle_downloaded_block(%BlockApplication{number: 3_000})

    synced_height = 2
    next_synced_height = synced_height + 1

    assert {[application1, application2], 0, [], state} =
             Core.get_blocks_to_apply(
               state,
               [%{blknum: 1_000, eth_height: synced_height}, %{blknum: 2_000, eth_height: synced_height}],
               synced_height
             )

    assert {state, 0, []} = Core.apply_block(state, application1)

    assert {state, ^synced_height, [{:put, :last_block_getter_eth_height, ^synced_height}]} =
             Core.apply_block(state, application2)

    assert {[application3], ^synced_height, [], state} =
             Core.get_blocks_to_apply(state, [%{blknum: 3_000, eth_height: next_synced_height}], next_synced_height)

    assert {state, ^next_synced_height, [{:put, :last_block_getter_eth_height, ^next_synced_height}]} =
             Core.apply_block(state, application3)

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
      init_state(synced_height: 58, start_block_number: 1_000, init_opts: [maximum_number_of_pending_blocks: 3])
      |> Core.get_numbers_of_blocks_to_download(16_000_000)
      |> assert_check([2_000, 3_000, 4_000])
      |> handle_downloaded_block(%BlockApplication{number: 2_000})
      |> handle_downloaded_block(%BlockApplication{number: 3_000})
      |> handle_downloaded_block(%BlockApplication{number: 4_000})

    # coordinator dwells in the past
    assert {[], 58, [], _} = Core.get_blocks_to_apply(state, take_submissions.({58, 58}), 58)

    # coordinator allows into the future
    assert {[application0, application1000], 58, [], state_alt} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 60)),
               60
             )

    assert {_, 59, [{:put, :last_block_getter_eth_height, 59}]} = Core.apply_block(state_alt, application0)
    assert {_, 60, [{:put, :last_block_getter_eth_height, 60}]} = Core.apply_block(state_alt, application1000)

    # coordinator on time
    assert {[^application0], 58, [], state} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 59)),
               59
             )

    assert {state, 59, [{:put, :last_block_getter_eth_height, 59}]} = Core.apply_block(state, application0)

    state =
      state
      |> Core.get_numbers_of_blocks_to_download(16_000_000)
      |> assert_check([5_000, 6_000, 7_000])
      |> handle_downloaded_block(%BlockApplication{number: 5_000})
      |> handle_downloaded_block(%BlockApplication{number: 6_000})

    # coordinator dwells in the past
    assert {[], 59, [], ^state} = Core.get_blocks_to_apply(state, take_submissions.({59, 59}), 59)

    # coordinator allows into the future
    assert {[^application1000, application4000, application5000], 59, [], state_alt} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 61)),
               61
             )

    assert {state_alt, 60, [{:put, :last_block_getter_eth_height, 60}]} = Core.apply_block(state_alt, application1000)
    assert {state_alt, 60, []} = Core.apply_block(state_alt, application4000)
    assert {_, 61, [{:put, :last_block_getter_eth_height, 61}]} = Core.apply_block(state_alt, application5000)

    # coordinator on time
    assert {[^application1000], 59, [], state} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 60)),
               60
             )

    assert {state, 60, [{:put, :last_block_getter_eth_height, 60}]} = Core.apply_block(state, application1000)

    # coordinator dwells in the past
    assert {[], 60, [], ^state} = Core.get_blocks_to_apply(state, take_submissions.({60, 60}), 60)

    # coordinator allows into the future
    assert {[^application4000, ^application5000], 60, [], state_alt} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 62)),
               62
             )

    assert {state_alt, 60, []} = Core.apply_block(state_alt, application4000)
    assert {_, 61, [{:put, :last_block_getter_eth_height, 61}]} = Core.apply_block(state_alt, application5000)

    # coordinator on time
    assert {[^application4000, ^application5000], 60, [], state} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 61)),
               61
             )

    assert {state, 60, []} = Core.apply_block(state, application4000)
    assert {state, 61, [{:put, :last_block_getter_eth_height, 61}]} = Core.apply_block(state, application5000)

    # coordinator dwells in the past
    assert {[], 61, [], ^state} = Core.get_blocks_to_apply(state, take_submissions.({61, 61}), 61)

    # coordinator allows into the future
    assert {[application6000], 61, [], state_alt} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 63)),
               63
             )

    application7000 = %BlockApplication{number: 7_000, eth_height: 63, eth_height_done: true}

    assert {state_alt, 61, []} = Core.apply_block(state_alt, application6000)
    assert {_, 63, [{:put, :last_block_getter_eth_height, 63}]} = Core.apply_block(state_alt, application7000)

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
    assert {[^application6000], 62, [], state_alt} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 64)),
               64
             )

    assert {_, 62, []} = Core.apply_block(state_alt, application6000)

    # coordinator on time
    assert {[^application6000], 62, [], state} =
             Core.get_blocks_to_apply(
               state,
               take_submissions.(Core.get_eth_range_for_block_submitted_events(state, 63)),
               63
             )

    assert {state, 62, []} = Core.apply_block(state, application6000)
    assert {_, 63, [{:put, :last_block_getter_eth_height, 63}]} = Core.apply_block(state, application7000)
  end

  test "gets continous ranges of blocks to apply" do
    state =
      init_state(synced_height: 0, init_opts: [maximum_number_of_pending_blocks: 5])
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([1_000, 2_000, 3_000, 4_000])
      |> handle_downloaded_block(%BlockApplication{number: 1_000})
      |> handle_downloaded_block(%BlockApplication{number: 3_000})
      |> handle_downloaded_block(%BlockApplication{number: 4_000})

    {[%BlockApplication{eth_height: 1, eth_height_done: true}], _, _, state} =
      Core.get_blocks_to_apply(state, [%{blknum: 1_000, eth_height: 1}, %{blknum: 2_000, eth_height: 2}], 2)

    state = state |> handle_downloaded_block(%BlockApplication{number: 2_000})

    {[%BlockApplication{eth_height: 2, eth_height_done: true}], _, _, _} =
      Core.get_blocks_to_apply(state, [%{blknum: 1_000, eth_height: 1}, %{blknum: 2_000, eth_height: 2}], 2)
  end

  test "do not download blocks when there are too many downloaded blocks not yet applied" do
    state =
      init_state(
        synced_height: 0,
        init_opts: [maximum_number_of_pending_blocks: 5, maximum_number_of_unapplied_blocks: 3]
      )
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([1_000, 2_000, 3_000])
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([])
      |> handle_downloaded_block(%BlockApplication{number: 1_000})
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([])

    synced_height = 1
    {_, _, _, state} = Core.get_blocks_to_apply(state, [%{blknum: 1_000, eth_height: synced_height}], synced_height)

    {_, [4_000]} = Core.get_numbers_of_blocks_to_download(state, 5_000)
  end

  test "when State is not at the beginning should not init state properly" do
    assert init_state(state_at_beginning: false) == {:error, :not_at_block_beginning}
  end

  test "maximum_number_of_pending_blocks can't be too low" do
    assert init_state(init_opts: [maximum_number_of_pending_blocks: 0]) ==
             {:error, :maximum_number_of_pending_blocks_too_low}
  end

  test "BlockGetter omits submissions of already applied blocks" do
    state =
      init_state(synced_height: 1, start_block_number: 1000)
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([2_000, 3_000, 4_000])
      |> handle_downloaded_block(%BlockApplication{number: 2_000})

    submissions = [%{blknum: 1_000, eth_height: 1}, %{blknum: 2_000, eth_height: 2}]
    {[application], 1, [], state} = Core.get_blocks_to_apply(state, submissions, 2)

    # apply that and see if we won't get the same thing again
    {state, 2, _} = Core.apply_block(state, application)
    {[], 2, _, _} = Core.get_blocks_to_apply(state, submissions, 2)
  end

  test "an unapplied block appears in an already synced eth block (due to reorg)" do
    state =
      init_state(synced_height: 2, start_block_number: 1000)
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([2_000, 3_000, 4_000])
      |> handle_downloaded_block(%BlockApplication{number: 2_000})
      |> handle_downloaded_block(%BlockApplication{number: 3_000})

    {[
       %BlockApplication{number: 2_000, eth_height: 1, eth_height_done: true},
       %BlockApplication{number: 3_000, eth_height: 3, eth_height_done: true}
     ], 2, _,
     _} = Core.get_blocks_to_apply(state, [%{blknum: 2_000, eth_height: 1}, %{blknum: 3_000, eth_height: 3}], 3)
  end

  test "an already applied child chain block appears in a block above synced_height (due to a reorg)" do
    state =
      init_state(start_block_number: 1_000)
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([2_000, 3_000, 4_000])
      |> handle_downloaded_block(%BlockApplication{number: 2_000})

    {[%BlockApplication{number: 2_000, eth_height: 3, eth_height_done: true}], 1, [], _} =
      Core.get_blocks_to_apply(state, [%{blknum: 1_000, eth_height: 3}, %{blknum: 2_000, eth_height: 3}], 3)
  end

  test "apply block with eth_height lower than synced_height" do
    state =
      init_state(synced_height: 2)
      |> Core.get_numbers_of_blocks_to_download(2_000)
      |> assert_check([1_000])
      |> handle_downloaded_block(%BlockApplication{number: 1_000})

    {[application], 2, [], state} = Core.get_blocks_to_apply(state, [%{blknum: 1_000, eth_height: 1}], 3)
    {_, 1, _} = Core.apply_block(state, application)
  end

  test "apply a block that moved forward" do
    state =
      init_state(synced_height: 1, start_block_number: 1000)
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([2_000, 3_000, 4_000])

    # block 2_000 first appears at height 3
    {[], 1, [], state} =
      Core.get_blocks_to_apply(state, [%{blknum: 2_000, eth_height: 3}, %{blknum: 3_000, eth_height: 4}], 4)

    # download blocks
    state =
      state
      |> handle_downloaded_block(%BlockApplication{number: 2_000})
      |> handle_downloaded_block(%BlockApplication{number: 3_000})

    # block then moves forward
    {[application1, application2], 1, [], state} =
      Core.get_blocks_to_apply(state, [%{blknum: 2_000, eth_height: 4}, %{blknum: 3_000, eth_height: 4}], 4)

    # the block is applied at height it was first seen
    {state, 1, _} = Core.apply_block(state, application1)
    {_, 4, _} = Core.apply_block(state, application2)
  end

  test "apply a block that moved backward" do
    state =
      init_state(synced_height: 1, start_block_number: 1000)
      |> Core.get_numbers_of_blocks_to_download(5_000)
      |> assert_check([2_000, 3_000, 4_000])

    # block 2_000 first appears at height 3
    {[], 1, [], state} =
      Core.get_blocks_to_apply(state, [%{blknum: 2_000, eth_height: 3}, %{blknum: 3_000, eth_height: 4}], 4)

    # download blocks
    state =
      state
      |> handle_downloaded_block(%BlockApplication{number: 2_000})
      |> handle_downloaded_block(%BlockApplication{number: 3_000})

    # block then moves backward
    {[application1, application2], 1, [], state} =
      Core.get_blocks_to_apply(state, [%{blknum: 2_000, eth_height: 2}, %{blknum: 3_000, eth_height: 4}], 4)

    # the block is applied at updated height
    {state, 2, _} = Core.apply_block(state, application1)
    {_, 4, _} = Core.apply_block(state, application2)
  end

  test "move forward even though an applied block appears in submissions" do
    state =
      init_state(start_block_number: 1_000, synced_height: 2)
      |> Core.get_numbers_of_blocks_to_download(3_000)
      |> assert_check([2_000])

    {[], 3, [_], _} = Core.get_blocks_to_apply(state, [%{blknum: 1_000, eth_height: 1}], 3)
  end

  test "returns valid eth range" do
    # properly looks `block_getter_reorg_margin` number of blocks backward
    state = init_state(synced_height: 100, block_getter_reorg_margin: 10)
    assert {100 - 10, 101} == Core.get_eth_range_for_block_submitted_events(state, 101)

    # beginning of the range is no less than 0
    state = init_state(synced_height: 0, block_getter_reorg_margin: 10)
    assert {0, 101} == Core.get_eth_range_for_block_submitted_events(state, 101)
  end

  defp init_state(opts \\ []) do
    init_params =
      [
        start_block_number: 0,
        interval: 1_000,
        synced_height: 1,
        block_getter_reorg_margin: 5,
        state_at_beginning: true,
        exit_processor_results: {:ok, []},
        init_opts: []
      ]
      |> Keyword.merge(opts)
      |> Map.new()

    with {:ok, state} <-
           Core.init(
             init_params.start_block_number,
             init_params.interval,
             init_params.synced_height,
             init_params.block_getter_reorg_margin,
             init_params.state_at_beginning,
             init_params.exit_processor_results,
             init_params.init_opts
           ),
         do: state
  end

  # NOT Watcher Security concern
  describe "WatcherDB idempotency:" do
    #
    # NOT Watcher Security concern
    #
    # test "prevents older or block with the same blknum as previously consumed" do
    #   state = init_state(last_persisted_block: 3000)

    #   assert [] == Core.ensure_block_imported_once(%BlockApplication{number: 2000}, state)
    #   assert [] == Core.ensure_block_imported_once(%BlockApplication{number: 3000}, state)
    # end
    #
    # test "allows newer blocks to get consumed" do
    #   state = init_state(last_persisted_block: 3000)

    #   assert [
    #            %{
    #              eth_height: 1,
    #              blknum: 4000,
    #              blkhash: <<0::256>>,
    #              timestamp: 0,
    #              transactions: []
    #            }
    #          ] ==
    #            Core.ensure_block_imported_once(
    #              %BlockApplication{number: 4000, transactions: [], hash: <<0::256>>, timestamp: 0, eth_height: 1},
    #              state
    #            )
    # end

    # test "do not hold blocks when not properly initialized or DB empty" do
    #   state = init_state()

    #   assert [
    #            %{
    #              eth_height: 1,
    #              blknum: 4000,
    #              blkhash: <<0::256>>,
    #              timestamp: 0,
    #              transactions: []
    #            }
    #          ] ==
    #            Core.ensure_block_imported_once(
    #              %BlockApplication{number: 4000, transactions: [], hash: <<0::256>>, timestamp: 0, eth_height: 1},
    #              state
    #            )
    # end
  end
end
