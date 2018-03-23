defmodule OmiseGO.DB do
  @moduledoc """
  Our-types-aware port/adapter to the db backend
  """
  # TODO 1: iron out shell-core interactions
  # TODO 2: still needs to be integrated into other components and integration-tested

  ### Client (port)

  @server_name Application.get_env(:omisego_db, :server_name)

  def multi_update(db_updates, server_name \\ @server_name) do
    GenServer.call(server_name, {:multi_update, db_updates})
  end

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
    defstruct [:db_ref]

    use GenServer

    alias OmiseGO.DB.LevelDBCore

    import Exleveldb

    def start_link([name: name, db_path: db_path]) do
      GenServer.start_link(__MODULE__, %{db_path: db_path}, name: name)
    end

    def init(%{db_path: db_path}) do
      {:ok, db_ref} = open(db_path)
      {:ok, %__MODULE__{db_ref: db_ref}}
    end

    def handle_call({:tx, hash}, _from, %__MODULE__{db_ref: db_ref} = state) do
      result =
        with key <- LevelDBCore.tx_key(hash),
             {:ok, value} <- get(db_ref, key),
             do: {:ok, LevelDBCore.decode_value(:tx, value)}
      {:reply, result, state}
    end

    def handle_call({:blocks, blocks_to_fetch}, _from, %__MODULE__{db_ref: db_ref} = state) do
      result =
        blocks_to_fetch
        |> Enum.map(&LevelDBCore.block_key/1)
        |> Enum.map(fn key -> get(db_ref, key) end)
        |> Enum.map(fn {:ok, value} -> LevelDBCore.decode_value(:block, value) end)
      {:reply, {:ok, result}, state}
    end

    def handle_call({:utxos}, _from, %__MODULE__{db_ref: db_ref} = state) do
      with keys_stream <- stream(db_ref, :keys_only),
           utxo_keys <- LevelDBCore.filter_utxos(keys_stream),
           result <- utxo_keys
                     |> Enum.map(fn key -> get(db_ref, key) end)
                     |> Enum.map(fn {:ok, value} -> LevelDBCore.decode_value(:utxo, value) end),
           do: {:reply, {:ok, result}, state}
    end

    def handle_call({:multi_update, db_updates}, _from, %__MODULE__{db_ref: db_ref} = state) do
      operations =
        db_updates
        |> LevelDBCore.parse_multi_updates

      :ok = write(db_ref, operations)
      {:reply, :ok, state}
    end
  end
end
