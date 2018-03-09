defmodule OmiseGO.BlockCache do
  @moduledoc """
  Allows for quick scallable access to a fresh subset of blocks
  (do we need this?)
  """

  def add_block(block) do
    GenServer.cast(__MODULE__.Core, {:add_block, block})
  end

  def get_block(height) do
    # TODO: bottleneck because of the `call`, how to paralellize?
    {block, blocks_to_fetch} = GenServer.call(__MODULE__.Core, {:get_block, height})
    fetched_blocks = DB.blocks(blocks_to_fetch)
    Map.get(fetched_blocks, height, block)
  end

  defmodule Core do
    @moduledoc """
    Soon to be filled in a PR
    """

    defstruct [:blocks]

    use GenServer

    @cachesize 1024

    def handle_cast({:add_block, %{height: height} = block}, state) do
      state
      |> Map.delete(height - cache_size())
      |> Map.put(height, block)
    end

    def handle_call({:get_block, height}, state) do
      case Map.get(state, height) do
        nil -> {nil, [height]}
        block -> {block, []}
      end
    end

    defp cache_size do
      @cachesize # constant now, but can be adaptive to whatever
    end

  end

end
