defmodule OmiseGO.FreshBlocks do
  @moduledoc """
    Alows for quick access to a fresh subset of blocks
    (do we need this?)
    (makit as wraper to DB?)
  """

  # TODO remove this and import the true one
  defmodule Block do
    defstruct [:number]
  end

  ##### Client
  def start_ling() do
    GenServer.start_link(__MODULE__, :ok, __MODULE__)
  end

  @spec get(block_number :: integer) :: Block
  def get(block_number) do
    GenServer.call(__MODULE__, {:get, block_number})
  end

  @spec push(block :: Block) :: boolean
  def push(block) do
    GenServer.cast(__MODULE__, {:push, block})
  end

  ##### Core
  defmodule Core do
    defstruct container: %{}, max_size: 100, keys_queue: :queue.new()

    def get(block_number, state) do
      case Map.get(state.container, block_number) do
        nil -> {nil, [block_number]}
        block -> {block, []}
      end
    end

    def update(block, state) do
      keys_queue = :queue.snoc(state.keys_queue, block.number)
      container = Map.put(state.container, block.number, block)

      cond do
        state.max_size < Kernel.map_size(container) ->
          key_to_remove = :queue.get(state.keys_queue)

          {:ok,
           %{
             state
             | keys_queue: :queue.drop(keys_queue),
               container: Map.delete(container, key_to_remove)
           }}

        true ->
          {:ok, %{state | keys_queue: keys_queue, container: container}}
      end
    end
  end

  ##### Server
  use GenServer

  def init(:ok) do
    %Core{}
  end

  # when is_integer(block_number)
  def handle_call({:get, block_number}, _from, state) do
    {block, blocks_to_fetch} = Core.get(block_number, state)
    fetched_blocks = DB.blocks(blocks_to_fetch)
    {:reply, Map.get(fetched_blocks, block_number, block), state}
  end

  def handle_cast({:push, block = %Block{}}, _from, state) do
    {:ok, new_state} = Core.update(block, state)
    {:noreply, :ok, new_state}
  end
end
