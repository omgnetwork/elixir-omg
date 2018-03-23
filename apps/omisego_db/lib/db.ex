defmodule OmiseGO.DB do
  @moduledoc """
  Our-types-aware port/adapter to the db backend
  """
  # TODO 1: iron out shell-core interactions
  # TODO 2: still needs to be integrated into other components and integration-tested

  ### Client (port)

  def start_link do
    GenServer.start_link(OmiseGO.DB.LevelDBServer, :ok, name: OmiseGO.DB.LevelDBServer)
  end

  def stop do
    GenServer.stop(OmiseGO.DB.LevelDBServer, :normal)
  end

  def multi_update(db_updates) do
    GenServer.call(OmiseGO.DB.LevelDBServer, {:multi_update, db_updates})
  end

  def tx(hash) do
    GenServer.call(OmiseGO.DB.LevelDBServer, {:tx, hash})
  end

  # TODO: FreshBlocks fetches by block number and returns by block number, while we probably want by block hash
  @spec blocks(block_to_fetch :: list()) :: {:ok, map} | {:error, any}
  def blocks(blocks_to_fetch) do
    GenServer.call(OmiseGO.DB.LevelDBServer, {:blocks, blocks_to_fetch})
  end

  def utxos do
    GenServer.call(OmiseGO.DB.LevelDBServer, {:utxos})
  end

  def height do
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

    def init(:ok) do
      # TODO: handle file location properly - probably pass as parameter here and configure in DB.Application
      {:ok, db_ref} = open("/home/user/.omisego/data")
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
