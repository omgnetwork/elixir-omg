defmodule OmiseGO.FreshBlocks do
  @moduledoc """
    Allows for quick access to a fresh subset of blocks
  """
  alias OmiseGO.DB

  # TODO remove this and import the true one
  defmodule Block do
    @moduledoc """
    """
    defstruct [:number]
  end

  ##### Client
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @spec get(block_number :: integer) :: Block
  def get(block_number) do
    GenServer.call(__MODULE__, {:get, block_number})
  end

  def push(%Block{} = block) do
    GenServer.cast(__MODULE__, {:push, block})
  end

  def get_top_blocks(_number) do
    {:ok, []}
  end

  ##### Core
  defmodule Core do
    @moduledoc """
       core implementation
    """
    defstruct container: %{}, max_size: 100, keys_queue: :queue.new()

    def get(block_number, state) do
      case Map.get(state.container, block_number) do
        nil -> {nil, [block_number]}
        %Block{} = block -> {block, []}
      end
    end

    def update(block, state) do
      keys_queue = :queue.in(block.number, state.keys_queue)
      container = Map.put(state.container, block.number, block)

      if state.max_size < Kernel.map_size(container) do
        {{:value, key_to_remove}, keys_queue} = :queue.out(state.keys_queue)

        {:ok, %{state | keys_queue: keys_queue, container: Map.delete(container, key_to_remove)}}
      else
        {:ok, %{state | keys_queue: keys_queue, container: container}}
      end
    end
  end

  ##### Server
  use GenServer

  def init(:ok) do
    {:ok, %Core{}}
  end

  def handle_call({:get, block_number}, _from, %Core{} = state) do
    {block, blocks_to_fetch} = Core.get(block_number, state)
    fetched_blocks = DB.blocks(blocks_to_fetch)
    {:reply, Map.get(fetched_blocks, block_number, block), state}
  end

  def handle_cast({:push, %Block{} = block}, _from, state) do
    {:ok, new_state} = Core.update(block, state)
    {:noreply, :ok, new_state}
  end
end
