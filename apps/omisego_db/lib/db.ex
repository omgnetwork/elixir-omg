defmodule OmiseGO.DB do
  @moduledoc """
  Our-types-aware port/adapter to the db backend
  """
  # TODO 2: still needs to be integrated into other components and integration-tested

  ### Client (port)

  @server_name OmiseGO.DB.LevelDBServer

  def multi_update(db_updates, server_name \\ @server_name) do
    GenServer.call(server_name, {:multi_update, db_updates})
  end

  # TODO: this will likely be dropped from the OmiseGO.API and here
  def tx(hash, server_name \\ @server_name) do
    GenServer.call(server_name, {:tx, hash})
  end

  # TODO: FreshBlocks fetches by block number and returns by block number, while we probably want by block hash
  @spec blocks(block_to_fetch :: list()) :: {:ok, map} | {:error, any}
  def blocks(blocks_to_fetch, server_name \\ @server_name) do
    GenServer.call(server_name, {:blocks, blocks_to_fetch})
  end

  def utxos(server_name \\ @server_name) do
    GenServer.call(server_name, {:utxos})
  end

  def block_hashes(block_numbers_to_fetch) do
    GenServer.call(OmiseGO.DB.LevelDBServer, {:block_hashes, block_numbers_to_fetch})
  end

  def child_top_block_number do
    GenServer.call(OmiseGO.DB.LevelDBServer, {:child_top_block_number})
  end
end
