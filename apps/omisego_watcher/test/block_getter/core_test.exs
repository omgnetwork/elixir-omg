defmodule OmiseGOWatcher.BlockGetter.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OmiseGO.API.Fixtures
  use Plug.Test

  alias OmiseGO.API.Block
  alias OmiseGOWatcher.BlockGetter.Core

  test "run block get task" do
    block_height = 0
    interval = 1_000
    chunk_size = 4
    state = Core.init(block_height, interval, chunk_size)

    {state_after_chunk, block_numbers} = Core.get_new_blocks_numbers(state, 20_000)
    assert block_numbers == [1_000, 2_000, 3_000, 4_000]

    assert %{task: %{run: 4}, block_info: %{started_height: 4_000}} = state_after_chunk

    state_after_proces_down =
      state_after_chunk
      |> Core.task_complited()
      |> Core.task_complited()

    assert %{task: %{run: 2}} = state_after_proces_down

    {state_after_second_chunk, block_numbers} = Core.get_new_blocks_numbers(state_after_proces_down, 20_000)
    assert block_numbers == [5_000, 6_000]

    assert %{task: %{run: 4}, block_info: %{started_height: 6_000}} = state_after_second_chunk
  end

  test "block management" do
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

    assert {%{block_info: %{consume: 0}}, []} = Core.get_blocks_to_consume(state)

    assert {%{block_info: %{consume: 3_000}}, [%Block{number: 1_000}, %Block{number: 2_000}, %Block{number: 3_000}]} =
             state |> Core.add_block(%Block{number: 1_000}) |> Core.get_blocks_to_consume()

    assert {%{block_info: %{consume: 6_000}},
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
end
