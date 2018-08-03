defmodule OmiseGO.DB.LevelDBServer do
  @moduledoc """
  Server handling a db connection to leveldb.
  All complex operations on data written/read should go into OmiseGO.DB.LevelDBCore
  """

  defstruct [:db_ref]

  use GenServer

  alias OmiseGO.DB.LevelDBCore

  alias Exleveldb

  def start_link(name: name, db_path: db_path) do
    GenServer.start_link(__MODULE__, %{db_path: db_path}, name: name)
  end

  def init(%{db_path: db_path}) do
    # needed so that terminate callback is called on normal close
    Process.flag(:trap_exit, true)
    {:ok, db_ref} = Exleveldb.open(db_path)
    {:ok, %__MODULE__{db_ref: db_ref}}
  end

  def handle_call({:multi_update, db_updates}, _from, %__MODULE__{db_ref: db_ref} = state) do
    result =
      db_updates
      |> LevelDBCore.parse_multi_updates()
      |> write(db_ref)

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

  def handle_call({:block_hashes, block_numbers_to_fetch}, _from, %__MODULE__{db_ref: db_ref} = state) do
    result =
      block_numbers_to_fetch
      |> Enum.map(fn block_number -> LevelDBCore.key(:block_hash, block_number) end)
      |> Enum.map(fn key -> get(key, db_ref) end)
      |> LevelDBCore.decode_values(:block_hash)

    {:reply, result, state}
  end

  @single_value_parameter_names [
    :child_top_block_number,
    :last_deposit_block_height,
    :last_fast_exit_block_height,
    :last_slow_exit_block_height
  ]

  def handle_call(parameter, _from, %__MODULE__{db_ref: db_ref} = state)
      when is_atom(parameter) and parameter in @single_value_parameter_names do
    result =
      parameter
      |> LevelDBCore.key(nil)
      |> get(db_ref)
      |> LevelDBCore.decode_value(parameter)

    {:reply, result, state}
  end

  # WARNING, terminate below will be called only if :trap_exit is set to true
  def terminate(_reason, %__MODULE__{db_ref: db_ref}) do
    :ok = Exleveldb.close(db_ref)
  end

  # Argument order flipping tools :(

  defp write(operations, db_ref) do
    Exleveldb.write(db_ref, operations)
  end

  defp get(key, db_ref) do
    Exleveldb.get(db_ref, key)
  end
end
