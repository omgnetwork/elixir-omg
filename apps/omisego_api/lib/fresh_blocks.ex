defmodule OmiseGO.API.FreshBlocks do
  @moduledoc """
    Allows for quick access to a fresh subset of blocks
  """
  alias OmiseGO.DB

  alias OmiseGO.API.Block

  ##### Client
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec get(block_hash :: binary) :: {:ok, Block | :not_found} | {:error, any}
  def get(block_hash) do
    GenServer.call(__MODULE__, {:get, block_hash})
  end

  def push(block) do
    GenServer.cast(__MODULE__, {:push, block})
  end

  ##### Core
  defmodule Core do
    @moduledoc """
       core implementation
    """
    defstruct container: %{}, max_size: 100, keys_queue: :queue.new()

    def get(block_hash, %__MODULE__{} = state) do
      case Map.get(state.container, block_hash) do
        nil -> {nil, [block_hash]}
        %Block{} = block -> {block, []}
      end
    end

    def push(%Block{} = block, %__MODULE__{} = state) do
      keys_queue = :queue.in(block.hash, state.keys_queue)
      container = Map.put(state.container, block.hash, block)

      if state.max_size < Kernel.map_size(container) do
        {{:value, key_to_remove}, keys_queue} = :queue.out(state.keys_queue)

        {:ok, %{state | keys_queue: keys_queue, container: Map.delete(container, key_to_remove)}}
      else
        {:ok, %{state | keys_queue: keys_queue, container: container}}
      end
    end

    def combine_getting_results(nil = _fresh_block, {:ok, [db_block] = _fetched_blocks} = _db_result), do: db_block
    def combine_getting_results(fresh_block, _db_result), do: fresh_block
  end

  ##### Server
  use GenServer

  def init(:ok) do
    {:ok, %Core{}}
  end

  def handle_call({:get, block_hash}, _from, %Core{} = state) do
    result =
      with {fresh_block, block_hashes_to_fetch} <- Core.get(block_hash, state),
           {:ok, _} = db_result <- DB.blocks(block_hashes_to_fetch),
           do: {:ok, Core.combine_getting_results(fresh_block, db_result)}

    {:reply, result, state}
  end

  def handle_cast({:push, block}, state) do
    {:ok, new_state} = Core.push(block, state)
    {:noreply, new_state}
  end
end
