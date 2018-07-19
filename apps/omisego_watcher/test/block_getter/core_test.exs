defmodule OmiseGOWatcher.BlockGetter.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OmiseGO.API.Fixtures
  use Plug.Test

  alias OmiseGO.API
  alias OmiseGO.API.Block
  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.JSONRPC.Client
  alias OmiseGOWatcher.BlockGetter.Core

  @eth Crypto.zero_address()

  defp add_block(state, block) do
    assert {:ok, new_state} = Core.add_block(state, block)
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
      |> add_block(%Block{number: 4_000})
      |> add_block(%Block{number: 2_000})

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
      |> add_block(%Block{number: 2_000})
      |> add_block(%Block{number: 3_000})
      |> add_block(%Block{number: 6_000})
      |> add_block(%Block{number: 5_000})

    assert {_, []} = Core.get_blocks_to_consume(state)

    assert {new_state, [%Block{number: 1_000}, %Block{number: 2_000}, %Block{number: 3_000}]} =
             state |> add_block(%Block{number: 1_000}) |> Core.get_blocks_to_consume()

    assert {_, [%Block{number: 4_000}, %Block{number: 5_000}, %Block{number: 6_000}]} =
             new_state |> add_block(%Block{number: 4_000}) |> Core.get_blocks_to_consume()

    assert {_,
            [
              %Block{number: 1_000},
              %Block{number: 2_000},
              %Block{number: 3_000},
              %Block{number: 4_000},
              %Block{number: 5_000},
              %Block{number: 6_000}
            ]} =
             state
             |> add_block(%Block{number: 1_000})
             |> add_block(%Block{number: 4_000})
             |> Core.get_blocks_to_consume()
  end

  test "start block height is not zero" do
    block_height = 7_000
    interval = 100
    chunk_size = 4
    state = Core.init(block_height, interval, chunk_size)
    assert {state, [7_100, 7_200, 7_300, 7_400]} = Core.get_new_blocks_numbers(state, 20_000)

    assert {_, [%Block{number: 7_100}, %Block{number: 7_200}]} =
             state
             |> add_block(%Block{number: 7_100})
             |> add_block(%Block{number: 7_200})
             |> Core.get_blocks_to_consume()
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

  test "check error return by add_block" do
    block_height = 0
    interval = 1_000
    chunk_size = 5

    {state, [1_000]} = block_height |> Core.init(interval, chunk_size) |> Core.get_new_blocks_numbers(2_000)

    assert {:error, :duplicate} = state |> add_block(%Block{number: 1_000}) |> Core.add_block(%Block{number: 1_000})
    assert {:error, :unexpected_blok} = state |> Core.add_block(%Block{number: 2_000})
  end

  @tag fixtures: [:alice, :bob, :state_alice_deposit]
  test "simple decode block", %{alice: alice, bob: bob, state_alice_deposit: state_alice_deposit} do
    %Block{hash: requested_hash} =
      block =
      Block.hashed_txs_at(
        [
          API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 7}, {alice, 3}])
        ],
        26_000
      )

    assert {:ok, decoded_block} = Core.decode_validate_block(Client.encode(block), requested_hash, 26_000)

    block_height = 25_000
    interval = 1_000
    chunk_size = 10

    {state, _} = block_height |> Core.init(interval, chunk_size) |> Core.get_new_blocks_numbers(35_000)
    assert {:ok, state} = Core.add_block(state, decoded_block)
    assert {_, [%{transactions: [tx]}]} = Core.get_blocks_to_consume(state)

    # check feasability of transactions from block to consume at the API.State
    assert {:ok, _, _} = API.State.Core.exec(tx, %{@eth => 0}, state_alice_deposit)
  end

  @tag fixtures: [:alice]
  test "check error return by decode_block, incorrect_hash", %{alice: alice} do
    matching_bad_returned_hash = String.duplicate("A", 64)

    assert {:error, :incorrect_hash} ==
             %{
               "hash" => matching_bad_returned_hash,
               "transactions" => [
                 API.TestHelper.create_encoded(
                   [{1_000, 20, 0, alice}],
                   @eth,
                   [{alice, 100}]
                 )
               ],
               "number" => 23
             }
             |> Client.encode()
             |> Core.decode_validate_block(matching_bad_returned_hash, 23)
  end

  @tag fixtures: [:alice]
  test "check error return by decode_block, rlp decoding checks", %{alice: alice} do
    badly_rlped = "12321231AB2331"

    %Block{hash: hash} =
      block =
      Block.hashed_txs_at(
        [
          API.TestHelper.create_recovered(
            [{1_000, 20, 0, alice}],
            @eth,
            [{alice, 100}]
          ),
          # NOTE: need to use internals b/c need a malformed tx
          %Transaction.Recovered{
            signed_tx: %Transaction.Signed{signed_tx_bytes: badly_rlped},
            signed_tx_hash: Crypto.hash(badly_rlped)
          }
        ],
        1
      )

    assert {:error, :malformed_transaction_rlp} ==
             block
             |> Client.encode()
             |> Core.decode_validate_block(hash, 1)
  end

  test "check error return by decode_block, hash mismatch checks" do
    %Block{hash: _hash} = block = Block.hashed_txs_at([], 1)

    assert {:error, :bad_returned_hash} ==
             block
             |> Client.encode()
             |> Core.decode_validate_block(String.duplicate("A", 64), 1)
  end

  test "check error return by decode_block, hash decoding error" do
    %Block{hash: hash} = block = Block.hashed_txs_at([], 1)

    assert {:error, {:hash_decoding_error, _}} =
             block
             |> Client.encode()
             |> (fn block -> %{block | "hash" => String.duplicate("Z", 64)} end).()
             |> Core.decode_validate_block(hash, 1)
  end

  test "check error return by decode_block, API.Core.recover_tx checks" do
    %Block{hash: hash} = block = Block.hashed_txs_at([API.TestHelper.create_recovered([], @eth, [])], 1)

    assert {:error, :no_inputs} ==
             block
             |> Client.encode()
             |> Core.decode_validate_block(hash, 1)
  end

  test "the blknum is overriden by the requested one" do
    %Block{hash: hash} = block = Block.hashed_txs_at([], 1)

    assert {:ok, %{number: 2 = _overriden_number}} =
             block
             |> Client.encode()
             |> Core.decode_validate_block(hash, 2)
  end
end
