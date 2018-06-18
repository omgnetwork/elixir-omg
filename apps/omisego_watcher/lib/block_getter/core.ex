defmodule OmiseGOWatcher.BlockGetter.Core do
  @moduledoc """
  Functional core for BlockGetter
  """

  defstruct [:block_info, :block_to_consume, :task]

  @type t() :: %__MODULE__{
          block_info: %{consume: non_neg_integer, started_height: non_neg_integer, interval: pos_integer},
          block_to_consume: list(OmiseGO.API.Block.t()),
          task: %{run: non_neg_integer, max: pos_integer}
        }

  @spec init(non_neg_integer, pos_integer, pos_integer) :: %__MODULE__{}
  def init(block_number, child_block_interval, chunk_size \\ 10) do
    %__MODULE__{
      block_info: %{
        consume: block_number,
        started_height: block_number,
        interval: child_block_interval
      },
      block_to_consume: %{},
      task: %{run: 0, max: chunk_size}
    }
  end

  @spec get_new_blocks_numbers(%__MODULE__{}, non_neg_integer) :: {%__MODULE__{}, list(non_neg_integer)}
  def get_new_blocks_numbers(state, next_child) do
    first_block_number = state.block_info.started_height + state.block_info.interval
    empty_slot = state.task.max - state.task.run

    blocks_numbers =
      first_block_number
      |> Stream.iterate(&(&1 + state.block_info.interval))
      |> Stream.take_while(&(&1 < next_child))
      |> Enum.take(empty_slot)

    {%{
       state
       | task: %{state.task | run: length(blocks_numbers) + state.task.run},
         block_info: %{
           state.block_info
           | started_height: hd(Enum.take([state.block_info.started_height] ++ blocks_numbers, -1))
         }
     }, blocks_numbers}
  end

  @spec add_block(%__MODULE__{}, OmiseGO.API.Block.t()) :: %__MODULE__{}
  def add_block(state, block) do
    %{state | block_to_consume: Map.put(state.block_to_consume, block.number, block)}
  end

  @spec get_blocks_to_consume(%__MODULE__{}) :: {%__MODULE__{}, list(OmiseGO.API.Block.t())}
  def get_blocks_to_consume(state) do
    first_block_number = state.block_info.consume + state.block_info.interval

    elem =
      first_block_number
      |> Stream.iterate(&(&1 + state.block_info.interval))
      |> Enum.take_while(&Map.has_key?(state.block_to_consume, &1))

    block_to_consume = elem |> Enum.map(&Map.get(state.block_to_consume, &1))
    new_block_to_comsume = Map.drop(state.block_to_consume, elem)

    {%{
       state
       | block_to_consume: new_block_to_comsume,
         block_info: %{state.block_info | consume: List.last([state.block_info.consume] ++ elem)}
     }, block_to_consume}
  end

  @spec task_complited(%__MODULE__{}) :: %__MODULE__{}
  def task_complited(state), do: %{state | task: %{state.task | run: state.task.run - 1}}
end
