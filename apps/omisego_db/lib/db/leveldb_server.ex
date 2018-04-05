defmodule OmiseGO.DB.LevelDBServer do
  @moduledoc """
  Server handling a db connection to leveldb
  """

  defstruct [:db_ref]

  use GenServer

  alias OmiseGO.DB.LevelDBCore

  alias Exleveldb

  def start_link([name: name, db_path: db_path]) do
    GenServer.start_link(__MODULE__, %{db_path: db_path}, name: name)
  end

  def init(%{db_path: db_path}) do
    with :ok <- File.mkdir_p(db_path),
         {:ok, db_ref} <- Exleveldb.open(db_path),
         do: {:ok, %__MODULE__{db_ref: db_ref}}
  end

  def handle_call({:tx, hash}, _from, %__MODULE__{db_ref: db_ref} = state) do
    key = LevelDBCore.key(:tx, hash)

    result =
      key
      |> get(db_ref)
      |> LevelDBCore.decode_value(:tx)
    {:reply, result, state}
  end

  def handle_call({:blocks, blocks_to_fetch}, _from, %__MODULE__{db_ref: db_ref} = state) do
    result =
      blocks_to_fetch
      |> Enum.map(fn block -> LevelDBCore.key(:block, block) end)
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

  def handle_call({:block_hashes, _block_numbers_to_fetch}, _from, %__MODULE__{db_ref: _db_ref} = state) do
    {:reply, {:ok, []}, state}
  end

  def handle_call({:child_top_block_number}, _from, %__MODULE__{db_ref: _db_ref} = state) do
    {:reply, {:ok, 0}, state}
  end

  def handle_call(:last_deposit_block_height, _from, %__MODULE__{db_ref: db_ref} = state) do
    #TODO: initialize db with height 0
    result =
      with key <- LevelDBCore.key(:last_deposit_block_height),
           response <- get(key, db_ref),
           do: LevelDBCore.decode_value(response, :last_deposit_block_height)

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
