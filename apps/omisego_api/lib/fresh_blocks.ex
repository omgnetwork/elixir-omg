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

  @spec get(block_hash :: integer) :: {:ok, Block} | {:error, any}
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
  end

  ##### Server
  use GenServer

  def init(:ok) do
    {:ok, %Core{}}
  end

  def handle_call({:get, block_hash}, _from, %Core{} = state) do
    result =
      with {block, block_hashes_to_fetch} <- Core.get(block_hash, state),
           {:ok, fetched_blocks} <- DB.blocks(block_hashes_to_fetch),
           # FIXME: this is clearly a violation of rules. How should I combine these two results?
           fetched_blocks <- (if fetched_blocks == [], do: %{}, else: %{block_hash => hd(fetched_blocks)}),
           do: Map.get(fetched_blocks, block_hash, block)

    {:reply, result, state}
  end

  def handle_cast({:push, block}, state) do
    {:ok, new_state} = Core.push(block, state)
    {:noreply, new_state}
  end
end
