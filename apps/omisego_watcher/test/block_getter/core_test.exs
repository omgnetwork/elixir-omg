defmodule OmiseGOWatcher.BlockGetter.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OmiseGO.API.Fixtures
  use Plug.Test

  alias OmiseGO.API.Block
  alias OmiseGOWatcher.BlockGetter.Core

  @moduletag :integration

  test "get blocks numbers to download" do
    block_height = 0
    interval = 1_000
    chunk_size = 4
    state = Core.init(block_height, interval, chunk_size)

    {state_after_chunk, block_numbers} = Core.get_new_blocks_numbers(state, 20_000)
    assert block_numbers == [1_000, 2_000, 3_000, 4_000]

    state_after_proces_down =
      state_after_chunk
      |> Core.add_block(%Block{number: 4_000})
      |> Core.add_block(%Block{number: 2_000})

    assert {_, [5_000, 6_000]} = Core.get_new_blocks_numbers(state_after_proces_down, 20_000)
  end

  test "getting block to consume" do
    block_height = 0
    interval = 1_000
    chunk_size = 4

    state =
      block_height
      |> Core.init(interval, chunk_size)
      |> Core.add_block(%Block{number: 2_000})
      |> Core.add_block(%Block{number: 3_000})
      |> Core.add_block(%Block{number: 6_000})
      |> Core.add_block(%Block{number: 5_000})

    assert {_, []} = Core.get_blocks_to_consume(state)

    assert {new_state, [%Block{number: 1_000}, %Block{number: 2_000}, %Block{number: 3_000}]} =
             state |> Core.add_block(%Block{number: 1_000}) |> Core.get_blocks_to_consume()

    assert {_, [%Block{number: 4_000}, %Block{number: 5_000}, %Block{number: 6_000}]} =
             new_state |> Core.add_block(%Block{number: 4_000}) |> Core.get_blocks_to_consume()

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
             |> Core.add_block(%Block{number: 1_000})
             |> Core.add_block(%Block{number: 4_000})
             |> Core.get_blocks_to_consume()
  end

  test "same block arrive two times" do
    block_height = 0
    interval = 1_000
    chunk_size = 4

    assert {_, [%Block{number: 1_000}, %Block{number: 2_000, hash: "new"}]} =
             block_height
             |> Core.init(interval, chunk_size)
             |> Core.add_block(%Block{number: 2_000, hash: "old"})
             |> Core.add_block(%Block{number: 1_000})
             |> Core.add_block(%Block{number: 2_000, hash: "new"})
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
             |> Core.add_block(%Block{number: 7_100})
             |> Core.add_block(%Block{number: 7_200})
             |> Core.get_blocks_to_consume()
  end

  test "mismatch in hash" do
    assert {:error, :incorrect_hash} ==
             Core.decode_block(%{
               "hash" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
               "transactions" => [],
               "number" => 23
             })
  end
end
