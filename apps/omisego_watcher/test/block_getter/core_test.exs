defmodule OmiseGOWatcher.BlockGetter.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OmiseGO.API.Fixtures
  use Plug.Test

  alias OmiseGO.API.{Block, State.Transaction}
  alias OmiseGO.API.TestHelper, as: API_Helper
  alias OmiseGO.JSONRPC.Client
  alias OmiseGOWatcher.BlockGetter.Core

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
             state
             |> add_block(%Block{number: 1_000})
             |> Core.get_blocks_to_consume()

    assert {_, [%Block{number: 4_000}, %Block{number: 5_000}, %Block{number: 6_000}]} =
             new_state
             |> add_block(%Block{number: 4_000})
             |> Core.get_blocks_to_consume()

    assert {
             _,
             [
               %Block{number: 1_000},
               %Block{number: 2_000},
               %Block{number: 3_000},
               %Block{number: 4_000},
               %Block{number: 5_000},
               %Block{number: 6_000}
             ]
           } =
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

    {state, [1_000]} = block_height
                       |> Core.init(interval, chunk_size)
                       |> Core.get_new_blocks_numbers(2_000)

    assert {:error, :duplicate} = state
                                  |> add_block(%Block{number: 1_000})
                                  |> Core.add_block(%Block{number: 1_000})
    assert {:error, :unexpected_blok} = state
                                        |> Core.add_block(%Block{number: 2_000})
  end

  test "simple decode block" do
    %Block{transactions: transactions} =
      block =
        Block.merkle_hash(
          %Block{
            transactions: [
              API_Helper.create_recovered([], Transaction.zero_address(), []),
              API_Helper.create_recovered([], Transaction.zero_address(), [])
            ],
            number: 1_000
          }
        )

    json =
      for {key, val} <- Map.from_struct(Map.put(block, :transactions, Enum.map(transactions, & &1.signed_tx_bytes))),
          into: %{},
          do: {Atom.to_string(key), val}

    assert {:ok, block} == Core.decode_block(Client.encode(json))
  end

  test "check error return by decode_block" do
    assert {:error, :incorrect_hash} ==
             Core.decode_block(
               %{
                 "hash" => String.duplicate("A", 64),
                 "transactions" => [
                   Client.encode(API_Helper.create_recovered([], Transaction.zero_address(), []).signed_tx_bytes)
                 ],
                 "number" => 23
               }
             )

    assert {:error, :malformed_transaction_rlp} ==
             Core.decode_block(
               %{
                 "hash" => "",
                 "transactions" => [
                   Client.encode(API_Helper.create_recovered([], Transaction.zero_address(), []).signed_tx_bytes),
                   "12321231AB2331"
                 ],
                 "number" => 1
               }
             )
  end

  test "check error return by add_potential_block_withholding" do
    block_height = 0
    interval = 1_000
    chunk_size = 4
    maximum_block_withholding_time = 0
    state = Core.init(block_height, interval, chunk_size, maximum_block_withholding_time)

    {:ok, new_state} = Core.add_potential_block_withholding(state, 1)

    Process.sleep(1000)

    assert {:error, :block_withholding, 1} == Core.add_potential_block_withholding(new_state, 1)
  end

end
