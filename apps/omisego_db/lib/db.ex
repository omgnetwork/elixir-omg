defmodule OmiseGO.DB do
  @moduledoc """
  Our-types-aware port/adapter to the db backend
  """

  ### Client (port)

  @server_name OmiseGO.DB.LevelDBServer

  def multi_update(db_updates, server_name \\ @server_name) do
    GenServer.call(server_name, {:multi_update, db_updates})
  end

  # TODO: this will likely be dropped from the OmiseGO.API and here
  def tx(hash, server_name \\ @server_name) do
    GenServer.call(server_name, {:tx, hash})
  end

  @spec blocks(block_to_fetch :: list()) :: {:ok, list()} | {:error, any}
  def blocks(blocks_to_fetch, server_name \\ @server_name) do
    GenServer.call(server_name, {:blocks, blocks_to_fetch})
  end

  def utxos(server_name \\ @server_name) do
    GenServer.call(server_name, {:utxos})
  end

  def block_hashes(block_numbers_to_fetch, server_name \\ @server_name) do
    GenServer.call(server_name, {:block_hashes, block_numbers_to_fetch})
  end

  def last_deposit_height(server_name \\ @server_name) do
    GenServer.call(server_name, :last_deposit_block_height)
  end

  def child_top_block_number(server_name \\ @server_name) do
    GenServer.call(server_name, :child_top_block_number)
  end
end
