defmodule OmiseGO.DB do
  @moduledoc """
  Our-types-aware port/adapter to the db backend
  """
  # TODO 2: still needs to be integrated into other components and integration-tested

  ### Client (port)

  @server_name Application.get_env(:omisego_db, :server_name)

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

  def height(_server_name \\ @server_name) do
    :to_be_implemented
  end

  defmodule LevelDBServer do
    @moduledoc """
    Server handling a db connection to leveldb
    """
    # FIXME move to own file

    defstruct [:db_ref]

    use GenServer

    alias OmiseGO.DB.LevelDBCore

    alias Exleveldb

    def start_link([name: name, db_path: db_path]) do
      GenServer.start_link(__MODULE__, %{db_path: db_path}, name: name)
    end

    def init(%{db_path: db_path}) do
      {:ok, db_ref} = Exleveldb.open(db_path)
      {:ok, %__MODULE__{db_ref: db_ref}}
    end

    def handle_call({:tx, hash}, _from, %__MODULE__{db_ref: db_ref} = state) do
      result =
        hash
        |> LevelDBCore.tx_key()
        |> get(db_ref)
        |> LevelDBCore.decode_value(:tx)
      {:reply, result, state}
    end

    def handle_call({:blocks, blocks_to_fetch}, _from, %__MODULE__{db_ref: db_ref} = state) do
      result =
        blocks_to_fetch
        |> Enum.map(&LevelDBCore.block_key/1)
        |> Enum.map(fn key -> get(key, db_ref) end)
        |> LevelDBCore.decode_values(:block)
      {:reply, result, state}
    end

    def handle_call({:utxos}, _from, %__MODULE__{db_ref: db_ref} = state) do
      keys_stream = Exleveldb.stream(db_ref, :keys_only)

      result =
        keys_stream
        |> LevelDBCore.filter_utxos()
        |> Enum.map(fn key -> get(key, db_ref) end)
        |> LevelDBCore.decode_values(:utxo)
      {:reply, result, state}
    end

    def handle_call({:multi_update, db_updates}, _from, %__MODULE__{db_ref: db_ref} = state) do
      result =
        db_updates
        |> LevelDBCore.parse_multi_updates()
        |> write(db_ref)

      {:reply, result, state}
    end

    # Argument order flipping tools :(

    defp write(operations, db_ref) do
      Exleveldb.write(db_ref, operations)
    end

    defp get(key, db_ref) do
      Exleveldb.get(db_ref, key)
    end
  end
end
