defmodule OmiseGo.BlockCache do
  @moduledoc """
    Alows for quick access to a fresh subset of blocks
    (do we need this?)
    (makit as wraper to DB?)
  """
  ##### Client
  def start_ling() do
    GenServer.start_link(__MODULE__, :ok, __MODULE__)
  end

  @spec get(block_number::integer)::Block
  def get(block_number) do
    GenServer.call(__MODULE__, {:get, block_number})
  end

  @spec push_block(block::Block)::boolean
  def push(block) do
    GenServer.cast(__MODULE__, {:push, block})
  end

  ##### Server
  use GenServer

  def init(:ok) do
      %Core{}
  end

  def handle_call({:get, block_number}, _from, state) do #when is_integer(block_number)
        case Core.contain?(block_number,state) do
            true -> {:reply, Core.get(block_number,state), state}
            false -> {:reply, DB.block(block_number), state}
        end
  end

  def handle_cast({:push, block = %Block{}}, _from, state) do
    {:noreply, :ok, Core.update(block,state)}
  end

  ##### Core
  defmodule Core do
    @defstrust size: 0, container: %{}, max_size: 100
    def get(block_number, state) do
       state[block_number]
    end

    def update(block, state) do
      #remove oldeset variable if max_size reach
      {:ok, Map.put(state,block.number,block)}
    end

    def contain?(block_number, state) do
        Map.has_key?(state,block_number)
    end
  end
end
