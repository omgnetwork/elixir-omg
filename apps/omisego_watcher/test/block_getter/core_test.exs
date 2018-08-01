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
    assert {:ok, new_state, _, []} = Core.got_block(state, {:ok, block})
    new_state
  end

  test "get blocks numbers to download" do
    block_height = 0
    interval = 1_000
    chunk_size = 4
    state = Core.init(block_height, interval, chunk_size)

    {state_after_chunk, block_numbers} = Core.get_new_blocks_numbers(state, 20_000)
    assert block_numbers == [1_000, 2_000, 3_000, 4_000]

    state_after_proces_down =
      state_after_chunk
      |> got_block(%Block{number: 4_000})
      |> got_block(%Block{number: 2_000})

    assert {_, [5_000, 6_000]} = Core.get_new_blocks_numbers(state_after_proces_down, 20_000)
  end

  test "getting block to consume" do
    block_height = 0
    interval = 1_000
    chunk_size = 6

    state =
      block_height
      |> Core.init(interval, chunk_size)
      |> Core.get_new_blocks_numbers(7_000)
      |> elem(0)
      |> got_block(%Block{number: 2_000})
      |> got_block(%Block{number: 3_000})
      |> got_block(%Block{number: 6_000})

    assert {:ok, state1, [], []} = Core.got_block(state, {:ok, %Block{number: 5_000}})

    assert {:ok, state2, [%Block{number: 1_000}, %Block{number: 2_000}, %Block{number: 3_000}], []} =
             state1 |> Core.got_block({:ok, %Block{number: 1_000}})

    assert {:ok, _, [%Block{number: 4_000}, %Block{number: 5_000}, %Block{number: 6_000}], []} =
             state2 |> Core.got_block({:ok, %Block{number: 4_000}})
  end

  test "getting blocks to consume out of order" do
    block_height = 0
    interval = 1_000
    chunk_size = 6

    assert {:ok, state, [], []} =
             block_height
             |> Core.init(interval, chunk_size)
             |> Core.get_new_blocks_numbers(7_000)
             |> elem(0)
             |> got_block(%Block{number: 3_000})
             |> Core.got_block({:ok, %Block{number: 2_000}})

    assert {:ok, _, [%Block{number: 1_000}, %Block{number: 2_000}, %Block{number: 3_000}], []} =
             state |> Core.got_block({:ok, %Block{number: 1_000}})
  end

  test "start block height is not zero" do
    block_height = 7_000
    interval = 100
    chunk_size = 4
    state = Core.init(block_height, interval, chunk_size)
    assert {state, [7_100, 7_200, 7_300, 7_400]} = Core.get_new_blocks_numbers(state, 20_000)

    assert {:ok, _, [%Block{number: 7_100}, %Block{number: 7_200}], []} =
             state
             |> got_block(%Block{number: 7_200})
             |> Core.got_block({:ok, %Block{number: 7_100}})
  end

  test "next_child increases or decrease in calls to get_new_blocks_numbers" do
    block_height = 0
    interval = 1_000
    chunk_size = 5

    {state, [1_000, 2_000, 3_000]} =
      block_height
      |> Core.init(interval, chunk_size)
      |> Core.get_new_blocks_numbers(4_000)

    assert {^state, []} = Core.get_new_blocks_numbers(state, 2_000)
    assert {_, [4_000, 5_000]} = Core.get_new_blocks_numbers(state, 8_000)
  end

  test "check error return by got_block" do
    block_height = 0
    interval = 1_000
    chunk_size = 5

    {state, [1_000, 2_000]} = block_height |> Core.init(interval, chunk_size) |> Core.get_new_blocks_numbers(3_000)

    assert {:error, :duplicate} =
             state |> got_block(%Block{number: 2_000}) |> Core.got_block({:ok, %Block{number: 2_000}})

    assert {:error, :unexpected_blok} = state |> Core.got_block({:ok, %Block{number: 3_000}})
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "simple decode block", %{alice: alice, bob: bob, state_alice_deposit: state_alice_deposit} do
    block =
      Block.hashed_txs_at(
        [
          API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}])
        ],
        26_000
      )

    assert {:ok, _, [%{transactions: [tx], zero_fee_requirements: fees}], _} = process_single_block(block)

    # check feasability of transactions from block to consume at the API.State
    assert {:ok, _, _} = API.State.Core.exec(tx, fees, state_alice_deposit)
  end

  @tag fixtures: [:alice, :bob]
  test "can decode and exec tx with different currencies, always with no fee required", %{alice: alice, bob: bob} do
    other_currency = <<1::160>>

    block =
      Block.hashed_txs_at(
        [
          API.TestHelper.create_recovered([{1, 0, 0, alice}], other_currency, [{bob, 7}, {alice, 3}]),
          API.TestHelper.create_recovered([{2, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}])
        ],
        26_000
      )

    assert {:ok, _, [%{transactions: [_tx1, _tx2], zero_fee_requirements: fees}], []} = process_single_block(block)

    assert fees == %{@eth => 0, other_currency => 0}
  end

  defp process_single_block(%Block{hash: requested_hash} = block) do
    block_height = 25_000
    interval = 1_000
    chunk_size = 10

    {state, _} =
      block_height |> Core.init(interval, chunk_size) |> Core.get_new_blocks_numbers(block_height + 2 * interval)

    assert {:ok, decoded_block} = Core.decode_validate_block({:ok, block}, requested_hash, block_height + interval)

    Core.got_block(state, {:ok, decoded_block})
  end

  @tag fixtures: [:alice]
  test "check error return by decode_block and got_block, incorrect_hash", %{alice: alice} do
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

    assert {:error, :incorrect_hash, matching_bad_returned_hash, 1} ==
             Core.decode_validate_block({:ok, block}, matching_bad_returned_hash, 1)

    assert {:error, _, _,
            [%Event.InvalidBlock{error_type: :incorrect_hash, hash: ^matching_bad_returned_hash, number: 1}]} =
             Core.got_block(state, {:error, :incorrect_hash, matching_bad_returned_hash, 1})
  end

  @tag fixtures: [:alice]
  test "check error return by decode_block, one of API.Core.recover_tx checks",
       %{alice: alice} do
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
    assert {:error, :no_inputs, hash, 1} == Core.decode_validate_block({:ok, block}, hash, 1)
  end

  test "check error return by decode_block, hash mismatch checks" do
    hash = <<12::256>>
    block = Block.hashed_txs_at([], 1)

    assert {:error, :bad_returned_hash, hash, 1} == Core.decode_validate_block({:ok, block}, hash, 1)
  end

  test "check error return by decode_block, API.Core.recover_tx checks" do
    %Block{hash: hash} = block = Block.hashed_txs_at([API.TestHelper.create_recovered([], @eth, [])], 1)

    assert {:error, :no_inputs, hash, 1} == Core.decode_validate_block({:ok, block}, hash, 1)
  end

  test "the blknum is overriden by the requested one" do
    %Block{hash: hash} = block = Block.hashed_txs_at([], 1)

    assert {:ok, %{number: 2 = _overriden_number}} = Core.decode_validate_block({:ok, block}, hash, 2)
  end

  test "got_block function called once with PotentialWithholding don't returns BlockWithHolding event" do
    block_height = 0
    interval = 1_000
    chunk_size = 5

    {state, [1_000, 2_000]} = block_height |> Core.init(interval, chunk_size) |> Core.get_new_blocks_numbers(3_000)

    potential_withholding = Core.decode_validate_block({:error, :error_reson}, <<>>, 2_000)

    assert {:ok, _, [], []} = Core.got_block(state, potential_withholding)
  end

  test "got_block function called twice with PotentialWithholding returns BlockWithHolding event" do
    block_height = 0
    interval = 1_000
    chunk_size = 5
    maximum_block_withholding_time = 0

    {state, [1_000, 2_000]} =
      Core.get_new_blocks_numbers(Core.init(block_height, interval, chunk_size, maximum_block_withholding_time), 3_000)

    potential_withholding = Core.decode_validate_block({:error, :error_reson}, <<>>, 2_000)

    assert {:ok, state, [], []} = Core.got_block(state, potential_withholding)

    Process.sleep(10)

    assert {:error, _, [], [%Event.BlockWithHolding{blknum: 2000}]} =
             Core.got_block(state, {:ok, %Core.PotentialWithholding{blknum: 2_000}})
  end

  test "get_new_blocks_numbers function returns number of potential withholding block which next is canceled" do
    block_height = 0
    interval = 1_000
    chunk_size = 4
    maximum_block_withholding_time = 0

    {state, [1_000, 2_000, 3_000, 4_000]} =
      Core.get_new_blocks_numbers(Core.init(block_height, interval, chunk_size, maximum_block_withholding_time), 20_000)

    state =
      state
      |> got_block(%Block{number: 1_000})
      |> got_block(%Block{number: 2_000})

    potential_withholding = Core.decode_validate_block({:error, :error_reson}, <<>>, 3_000)
    assert {:ok, state, [], []} = Core.got_block(state, potential_withholding)

    assert {_, [3000, 5000, 6000]} = Core.get_new_blocks_numbers(state, 20_000)

    state =
      state
      |> got_block(%Block{number: 3_000})

    assert {_, [5000, 6000, 7000, 8000]} = Core.get_new_blocks_numbers(state, 20_000)
  end

  test "got_block function after maximum_block_withholding_time returns BlockWithHolding event" do
    block_height = 0
    interval = 1_000
    chunk_size = 4
    maximum_block_withholding_time = 1000

    state = Core.init(block_height, interval, chunk_size, maximum_block_withholding_time)

    potential_withholding = Core.decode_validate_block({:error, :error_reson}, <<>>, 3_000)

    assert {:ok, %Core{potential_block_withholdings: %{3_000 => first_time}} = state, [], []} =
             Core.got_block(state, potential_withholding)

    :timer.sleep(500)
    assert :os.system_time(:millisecond) - first_time < maximum_block_withholding_time

    assert {:ok, %Core{potential_block_withholdings: %{3_000 => second_time}} = state, [], []} =
             Core.got_block(state, potential_withholding)

    :timer.sleep(500)
    assert :os.system_time(:millisecond) - second_time > maximum_block_withholding_time
    assert {:error, state, [], [%Event.BlockWithHolding{blknum: 3_000}]} = Core.got_block(state, potential_withholding)
  end
end
