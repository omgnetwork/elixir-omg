defmodule OmiseGO.API.FreshBlocks do
  @moduledoc """
  Allows for quick access to a fresh subset of blocks by keeping them in memory, independent of OmiseGO.DB.
  """

  use OmiseGO.API.LoggerExt

  alias OmiseGO.API.Block
  alias OmiseGO.API.FreshBlocks.Core
  alias OmiseGO.DB

  ##### Client
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec get(block_hash :: binary) :: {:ok, Block.t()} | {:error, :not_found | any}
  def get(block_hash) do
    GenServer.call(__MODULE__, {:get, block_hash})
  end

  def push(block) do
    GenServer.cast(__MODULE__, {:push, block})
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
           do: Core.combine_getting_results(fresh_block, db_result)

    _ = Logger.debug(fn -> "get block resulted with '#{inspect(result)}', block_hash '#{inspect(block_hash)}'" end)

    {:reply, result, state}
  end

  def handle_cast({:push, block}, state) do
    {:ok, new_state} = Core.push(block, state)
    _ = Logger.debug(fn -> "new block pushed, blknum '#{block.number}', hash '#{block.hash}'" end)

    {:noreply, new_state}
  end
end
