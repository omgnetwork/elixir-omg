defmodule OmiseGOWatcher.BlockGetter.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OmiseGO.API.Fixtures
  use Plug.Test

  alias OmiseGO.API
  alias OmiseGO.API.Block
  alias OmiseGO.API.Crypto
  alias OmiseGOWatcher.BlockGetter.Core
  alias OmiseGOWatcher.Eventer.Event

  @eth Crypto.zero_address()

  defp got_block(state, block) do
    assert {:ok, new_state, []} = Core.got_block(state, {:ok, block})
    new_state
  end

  test "get blocks numbers to download" do
    start_block_number = 0
    interval = 1_000
    chunk_size = 4
    synced_height = 1
    state = Core.init(start_block_number, interval, synced_height, chunk_size)

    {state_after_chunk, block_numbers} = Core.get_new_blocks_numbers(state, 20_000)
    assert block_numbers == [1_000, 2_000, 3_000, 4_000]

    state_after_proces_down =
      state_after_chunk
      |> got_block(%Block{number: 4_000})
      |> got_block(%Block{number: 2_000})

    assert {_, [5_000, 6_000]} = Core.get_new_blocks_numbers(state_after_proces_down, 20_000)
  end

  test "start block number is not zero" do
    start_block_number = 7_000
    interval = 100
    chunk_size = 4
    synced_height = 1
    state = Core.init(start_block_number, interval, synced_height, chunk_size)
    assert {state, [7_100, 7_200, 7_300, 7_400]} = Core.get_new_blocks_numbers(state, 20_000)

    assert {:ok, _, []} =
             state
             |> got_block(%Block{number: 7_200})
             |> Core.got_block({:ok, %Block{number: 7_100}})
  end

  test "does not get same blocks twice and respects increasing next block number" do
    start_block_number = 0
    interval = 1_000
    chunk_size = 5
    synced_height = 1

    {state, [1_000, 2_000, 3_000]} =
      start_block_number
      |> Core.init(interval, synced_height, chunk_size)
      |> Core.get_new_blocks_numbers(4_000)

    assert {^state, []} = Core.get_new_blocks_numbers(state, 2_000)
    assert {_, [4_000, 5_000]} = Core.get_new_blocks_numbers(state, 8_000)
  end

  test "got duplicated and unexpected block" do
    block_height = 0
    interval = 1_000
    chunk_size = 5

    {state, [1_000, 2_000]} = block_height |> Core.init(interval, chunk_size) |> Core.get_new_blocks_numbers(3_000)

    assert {:error, :duplicate} =
             state |> got_block(%Block{number: 2_000}) |> Core.got_block({:ok, %Block{number: 2_000}})

    assert {:error, :unexpected_block} = state |> Core.got_block({:ok, %Block{number: 3_000}})
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "decodes block and checks transaction execution", %{
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
             Core.get_blocks_to_consume(state, [%{blknum: block.number, eth_height: synced_height}], synced_height)

    # check feasability of transactions from block to consume at the API.State
    assert {:ok, tx_result, _} = API.State.Core.exec(tx, fees, state_alice_deposit)

    assert {:ok, []} = Core.check_tx_executions([{:ok, tx_result}], block)
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
             Core.get_blocks_to_consume(state, [%{blknum: block.number, eth_height: synced_height}], synced_height)

    assert fees == %{@eth => 0, other_currency => 0}
  end

  defp process_single_block(%Block{hash: requested_hash} = block) do
    block_height = 25_000
    interval = 1_000
    chunk_size = 10

    {state, _} =
      block_height |> Core.init(interval, chunk_size) |> Core.get_new_blocks_numbers(block_height + 2 * interval)

    assert {:ok, decoded_block} =
             Core.validate_get_block_response({:ok, block}, requested_hash, block_height + interval, 0)

    Core.got_block(state, {:ok, decoded_block})
  end

  @tag fixtures: [:alice]
  test "does not validate block with invalid hash", %{alice: alice} do
    block_height = 0
    interval = 1_000
    chunk_size = 5
    matching_bad_returned_hash = <<12::256>>

    state = Core.init(block_height, interval, chunk_size)

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
             Core.validate_get_block_response({:ok, block}, matching_bad_returned_hash, 0, 0)

    assert {{:needs_stopping, :incorrect_hash}, _,
            [%Event.InvalidBlock{error_type: :incorrect_hash, hash: ^matching_bad_returned_hash, number: 1}]} =
             Core.got_block(state, {:error, :incorrect_hash, matching_bad_returned_hash, 1})
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
    assert {:error, :no_inputs, hash, 1} == Core.validate_get_block_response({:ok, block}, hash, 1, 0)
  end

  test "check error returned by decode_block, hash mismatch checks" do
    hash = <<12::256>>
    block = Block.hashed_txs_at([], 1)

    assert {:error, :bad_returned_hash, hash, 1} == Core.validate_get_block_response({:ok, block}, hash, 1, 0)
  end

  test "check error returned by decode_block, API.Core.recover_tx checks" do
    %Block{hash: hash} = block = Block.hashed_txs_at([API.TestHelper.create_recovered([], @eth, [])], 1)

    assert {:error, :no_inputs, hash, 1} == Core.validate_get_block_response({:ok, block}, hash, 1, 0)
  end

  test "the blknum is overriden by the requested one" do
    %Block{hash: hash} = block = Block.hashed_txs_at([], 1)

    assert {:ok, %{number: 2 = _overriden_number}} = Core.validate_get_block_response({:ok, block}, hash, 2, 0)
  end

  test "got_block function called once with PotentialWithholding doesn't return BlockWithholding event" do
    block_height = 0
    interval = 1_000
    chunk_size = 5

    {state, [1_000, 2_000]} = block_height |> Core.init(interval, chunk_size) |> Core.get_new_blocks_numbers(3_000)

    potential_withholding = Core.validate_get_block_response({:error, :error_reson}, <<>>, 2_000, 0)

    assert {:ok, _, []} = Core.got_block(state, potential_withholding)
  end

  test "got_block function called twice with PotentialWithholding returns BlockWithholding event" do
    block_height = 0
    interval = 1_000
    chunk_size = 5
    synced_height = 1
    maximum_block_withholding_time = 0

    {state, [1_000, 2_000]} =
      Core.get_new_blocks_numbers(
        Core.init(block_height, interval, synced_height, chunk_size, maximum_block_withholding_time),
        3_000
      )

    potential_withholding = Core.validate_get_block_response({:error, :error_reson}, <<>>, 2_000, 0)
    assert {:ok, state, []} = Core.got_block(state, potential_withholding)

    potential_withholding = Core.validate_get_block_response({:error, :error_reson}, <<>>, 2_000, 1)

    assert {{:needs_stopping, :withholding}, _, [%Event.BlockWithholding{blknum: 2000}]} =
             Core.got_block(state, potential_withholding)
  end

  test "get_new_blocks_numbers function returns number of potential withholding block which next is canceled" do
    block_height = 0
    interval = 1_000
    chunk_size = 4
    synced_height = 1
    maximum_block_withholding_time = 0

    {state, [1_000, 2_000, 3_000, 4_000]} =
      Core.get_new_blocks_numbers(
        Core.init(block_height, interval, synced_height, chunk_size, maximum_block_withholding_time),
        20_000
      )

    state =
      state
      |> got_block(%Block{number: 1_000})
      |> got_block(%Block{number: 2_000})

    potential_withholding = Core.validate_get_block_response({:error, :error_reson}, <<>>, 3_000, 0)
    assert {:ok, state, []} = Core.got_block(state, potential_withholding)

    assert {_, [3000, 5000, 6000]} = Core.get_new_blocks_numbers(state, 20_000)

    assert {:ok, state, []} = Core.got_block(state, {:ok, %Block{number: 3_000}})

    assert {_, [5000, 6000, 7000, 8000]} = Core.get_new_blocks_numbers(state, 20_000)
  end

  test "got_block function after maximum_block_withholding_time returns BlockWithholding event" do
    block_height = 0
    interval = 1_000
    chunk_size = 4
    synced_height = 1
    maximum_block_withholding_time = 1000

    state = Core.init(block_height, interval, synced_height, chunk_size, maximum_block_withholding_time)

    potential_withholding = Core.validate_get_block_response({:error, :error_reson}, <<>>, 3_000, 0)

    assert {:ok, state, []} = Core.got_block(state, potential_withholding)

    potential_withholding = Core.validate_get_block_response({:error, :error_reson}, <<>>, 3_000, 500)

    assert {:ok, state, []} = Core.got_block(state, potential_withholding)

    potential_withholding = Core.validate_get_block_response({:error, :error_reson}, <<>>, 3_000, 1000)

    assert {{:needs_stopping, :withholding}, _state, [%Event.BlockWithholding{blknum: 3_000}]} =
             Core.got_block(state, potential_withholding)
  end

  test "check_tx_executions function returns InvalidBlock event" do
    block = %Block{number: 1, hash: <<>>}

    assert {{:needs_stopping, :tx_execution},
            [
              %Event.InvalidBlock{
                error_type: :tx_execution,
                hash: "",
                number: 1
              }
            ]} = Core.check_tx_executions([{:error, {}}], block)
  end

  test "does not return blocks to consume unless all blocks for a given parent height range are downloaded" do
    synced_height = 1
    state = Core.init(1_000, 1_000, synced_height, 4)
    next_synced_height = 4
    {state, [2_000, 3_000, 4_000, 5_000]} = Core.get_new_blocks_numbers(state, 6_000)

    state =
      state
      |> got_block(%Block{number: 2_000})
      |> got_block(%Block{number: 3_000})

    submissions = [%{blknum: 2_000, eth_height: 2}, %{blknum: 3_000, eth_height: 3}, %{blknum: 4_000, eth_height: 4}]

    {[], ^synced_height, [], ^state} = Core.get_blocks_to_consume(state, submissions, next_synced_height)

    state = got_block(state, %Block{number: 4_000})

    {[{%Block{number: 2_000}, 2}, {%Block{number: 3_000}, 3}, {%Block{number: 4_000}, 4}], ^synced_height, [], _state} =
      Core.get_blocks_to_consume(state, submissions, next_synced_height)
  end

  test "updates synced height when there are no new block submissions" do
    sync_height = 1
    rootchain_height = 2
    state = Core.init(1_000, 1_000, sync_height, 4)

    coordinator =
      OmiseGO.API.RootChainCoordinator.Core.init(MapSet.new([:block_getter, :other_service]), rootchain_height)

    coordinator =
      coordinator
      |> sync(:c.pid(0, 1, 0), rootchain_height, :other_service)
      |> sync(:c.pid(0, 2, 0), sync_height, :block_getter)

    {:sync, next_synced_height} = OmiseGO.API.RootChainCoordinator.Core.get_rootchain_height(coordinator)

    {^next_synced_height, ^next_synced_height, state} =
      Core.get_eth_range_for_block_submitted_events(state, next_synced_height)

    submissions = []

    {[], ^rootchain_height, [{:put, :block_getter_synced_height, ^rootchain_height}], state} =
      Core.get_blocks_to_consume(state, submissions, rootchain_height)

    coordinator = sync(coordinator, :c.pid(0, 2, 0), rootchain_height, :block_getter)
    {:sync, ^rootchain_height} = OmiseGO.API.RootChainCoordinator.Core.get_rootchain_height(coordinator)
    :empty_range = Core.get_eth_range_for_block_submitted_events(state, rootchain_height)
  end

  defp sync(coordinator, pid, height, service_name) do
    {:ok, coordinator} = OmiseGO.API.RootChainCoordinator.Core.sync(coordinator, pid, height, service_name)
    coordinator
  end

  test "updates synced height after all batched blocks have been processed" do
    block_getter_pid = :c.pid(0, 1, 0)
    synced_height = 1
    state = Core.init(1_000, 1_000, synced_height, 4)
    {state, _} = Core.get_new_blocks_numbers(state, 6_000)

    rootchain_height = 2
    coordinator = OmiseGO.API.RootChainCoordinator.Core.init(MapSet.new([:block_getter]), rootchain_height)
    coordinator = sync(coordinator, block_getter_pid, synced_height, :block_getter)

    {:sync, next_synced_height} = OmiseGO.API.RootChainCoordinator.Core.get_rootchain_height(coordinator)

    state =
      state
      |> got_block(%Block{number: 2_000})
      |> got_block(%Block{number: 3_000})

    {^next_synced_height, ^next_synced_height, state} =
      Core.get_eth_range_for_block_submitted_events(state, next_synced_height)

    submissions = [%{blknum: 2_000, eth_height: 2}, %{blknum: 3_000, eth_height: 2}]

    {[{%Block{number: 2_000}, 2}, {%Block{number: 3_000}, 2}], ^synced_height, [], state} =
      Core.get_blocks_to_consume(state, submissions, rootchain_height)

    {[], ^synced_height, [], state} = Core.get_blocks_to_consume(state, submissions, rootchain_height)

    state =
      state
      |> Core.consume_block(2_000)
      |> Core.consume_block(3_000)

    {[], ^rootchain_height, [{:put, :block_getter_synced_height, ^rootchain_height}], _state} =
      Core.get_blocks_to_consume(state, submissions, rootchain_height)
  end
end
