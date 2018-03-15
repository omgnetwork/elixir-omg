defmodule OmiseGO.DB do
  @moduledoc """
  Our-types-aware port/adapter to the db backend
  """

  ### Client (port)

  def start_link do
    GenServer.start_link(OmiseGO.DB.LevelDBServer, :ok, name: OmiseGO.DB.LevelDBServer)
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

  defmodule LevelDBServer do
    @moduledoc """
    Server handling a db connection to leveldb
    """
    defstruct [:db_ref]

    use GenServer

    alias OmiseGO.DB.LevelDBCore

    import Exleveldb

    def init(:ok) do
      {:ok, db_ref} = open("/home/user/.omisego/data")
      Process.flag(:trap_exit, true)
      {:ok, %__MODULE__{db_ref: db_ref}}
    end

    def handle_call({:tx, hash}, _from, %__MODULE__{db_ref: db_ref} = state) do
      result =
        with key <- LevelDBCore.tx_key(hash),
             {:ok, value} <- get(db_ref, key),
             {:ok, decoded} <- LevelDBCore.decode_value(:tx, value),
             do: {:ok, decoded}
      {:reply, result, state}
    end

    def handle_call({:blocks, blocks_to_fetch}, _from, %__MODULE__{db_ref: db_ref} = state) do
      result =
        blocks_to_fetch
        |> Enum.map(&LevelDBCore.block_key/1)
        |> Enum.map(fn key -> get(db_ref, key) end)
        |> Enum.map(fn {:ok, value} -> LevelDBCore.decode_value(:block, value) end)
      {:reply, result, state}
    end

    def handle_call({:utxos}, _from, %__MODULE__{db_ref: db_ref} = state) do
      with key <- LevelDBCore.utxo_list_key(),
           {:ok, utxo_list} <- get(db_ref, key),
           utxo_keys <- Enum.map(utxo_list, &LevelDBCore.utxo_key/1),
           result <- Enum.map(utxo_keys, fn key -> get(db_ref, key) end),
           do: {:reply, result, state}
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
