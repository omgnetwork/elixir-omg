defmodule OmiseGOWatcher.BlockGetter.Core do
  @moduledoc """
  Functional core for BlockGetter
  """
  def init(block_number, child_block_interval) do
    %{
      block_info: %{
        consume: block_number,
        started_height: block_number,
        height: block_number,
        interval: child_block_interval
      },
      acc: %{},
      task: %{run: 0, max: 10}
    }
  end

  def get_new_block_number_stream(state, next_child) do
    first_block_number = state.block_info.started_height + state.block_info.interval

    first_block_number
    |> Stream.iterate(&(&1 + state.block_info.interval))
    |> Enum.take_while(&(&1 < next_child))
  end

  def chunk(task_asynch, state) do
    empty_slot = state.task.max - state.task.run
    started_task = Enum.take(task_asynch, empty_slot)

    started_height =
      case List.last(started_task) do
        nil -> state.block_info.started_height
        {block_number, _pid} -> block_number
      end

    %{
      state
      | task: %{state.task | run: length(started_task) + state.task.run},
        block_info: %{state.block_info | started_height: started_height}
    }
  end

  def add_block(state, block) do
    %{state | acc: Map.put(state.acc, block.number, block)}
  end

  def get_blocks_to_consume(state) do
    first_block_number = state.block_info.consume + state.block_info.interval

    elem =
      first_block_number
      |> Stream.iterate(&(&1 + state.block_info.interval))
      |> Enum.take_while(&Map.has_key?(state.acc, &1))

    block_to_consume = elem |> Enum.map(&Map.get(state.acc, &1))
    new_acc = Map.drop(state.acc, elem)

    {%{
       state
       | acc: new_acc,
         block_info: %{state.block_info | consume: List.last([state.block_info.consume] ++ elem)}
     }, block_to_consume}
  end

  def process_down(state, _proccess), do: %{state | task: %{state.task | run: state.task.run - 1}}
end
