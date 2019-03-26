# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.DB.LevelDBServer do
  @moduledoc """
  Handles connection to leveldb
  """

  # All complex operations on data written/read should go into OMG.DB.LevelDBCore

  defstruct [:db_ref, :name]

  use GenServer
  alias OMG.DB.LevelDBCore
  alias OMG.DB.Recorder
  require Logger

  @doc """
  Initializes an empty LevelDB instance explicitly, so we can have control over it.
  NOTE: `init` here is to init the GenServer and that assumes that `init_storage` has already been called
  """
  @spec init_storage(binary) :: :ok | {:error, atom}
  def init_storage(db_path) do
    # open and close with the create flag set to true to initialize the LevelDB itself
    with {:ok, db_ref} <- Exleveldb.open(db_path, create_if_missing: true),
         true <- Exleveldb.is_empty?(db_ref) || {:error, :leveldb_not_empty},
         do: Exleveldb.close(db_ref)
  end

  def start_link(name: name, db_path: db_path) do
    GenServer.start_link(__MODULE__, %{db_path: db_path, name: name}, name: name)
  end

  def init(%{db_path: db_path, name: name}) do
    # needed so that terminate callback is called on normal close
    Process.flag(:trap_exit, true)

    name =
      name
      |> Atom.to_string()
      |> Kernel.<>(".Recorder")
      |> String.to_atom()

    {:ok, _recorder_pid} = Recorder.start_link(%Recorder{name: name, parent: self()})

    with {:ok, db_ref} <- Exleveldb.open(db_path, create_if_missing: false) do
      {:ok, %__MODULE__{name: name, db_ref: db_ref}}
    else
      error ->
        _ = Logger.error("It seems that Child chain database is not initialized. Check README.md")
        error
    end
  end

  def handle_call({:multi_update, db_updates}, _from, state) do
    result =
      db_updates
      |> LevelDBCore.parse_multi_updates()
      |> write(state)

    {:reply, result, state}
  end

  def handle_call({:blocks, blocks_to_fetch}, _from, state) do
    result =
      blocks_to_fetch
      |> Enum.map(fn block -> LevelDBCore.key(:block, block) end)
      |> Enum.map(fn key -> get(key, state) end)
      |> LevelDBCore.decode_values(:block)

    {:reply, result, state}
  end

  def handle_call(:utxos, _from, state) do
    result = get_all_by_type(:utxo, state)
    {:reply, result, state}
  end

  def handle_call(:exit_infos, _from, state) do
    result = get_all_by_type(:exit_info, state)
    {:reply, result, state}
  end

  def handle_call({:block_hashes, block_numbers_to_fetch}, _from, state) do
    result =
      block_numbers_to_fetch
      |> Enum.map(fn block_number -> LevelDBCore.key(:block_hash, block_number) end)
      |> Enum.map(fn key -> get(key, state) end)
      |> LevelDBCore.decode_values(:block_hash)

    {:reply, result, state}
  end

  def handle_call(:in_flight_exits_info, _from, state) do
    result = get_all_by_type(:in_flight_exit_info, state)
    {:reply, result, state}
  end

  def handle_call(:competitors_info, _from, state) do
    result = get_all_by_type(:competitor_info, state)
    {:reply, result, state}
  end

  def handle_call({:get_single_value, parameter}, _from, state)
      when is_atom(parameter) do
    result =
      parameter
      |> LevelDBCore.key(nil)
      |> get(state)
      |> LevelDBCore.decode_value(parameter)

    {:reply, result, state}
  end

  def handle_call({:exit_info, utxo_pos}, _from, state) do
    result =
      :exit_info
      |> LevelDBCore.key(utxo_pos)
      |> get(state)
      |> LevelDBCore.decode_value(:exit_info)

    {:reply, result, state}
  end

  def handle_call({:spent_blknum, utxo_pos}, _from, state) do
    result =
      :spend
      |> LevelDBCore.key(utxo_pos)
      |> get(state)
      |> LevelDBCore.decode_value(:spend)

    {:reply, result, state}
  end

  # WARNING, terminate below will be called only if :trap_exit is set to true
  def terminate(_reason, %__MODULE__{db_ref: db_ref}) do
    :ok = Exleveldb.close(db_ref)
  end

  # Argument order flipping tools :(
  defp write(operations, %__MODULE__{db_ref: db_ref, name: __MODULE__}) do
    _ = Recorder.update_write()
    Exleveldb.write(db_ref, operations)
  end

  defp write(operations, %__MODULE__{db_ref: db_ref, name: name}) do
    _ = Recorder.update_write(name)
    Exleveldb.write(db_ref, operations)
  end

  defp get(key, %__MODULE__{db_ref: db_ref, name: __MODULE__}) do
    _ = Recorder.update_read()
    Exleveldb.get(db_ref, key)
  end

  defp get(key, %__MODULE__{db_ref: db_ref, name: name}) do
    _ = Recorder.update_read(name)
    Exleveldb.get(db_ref, key)
  end

  defp get_all_by_type(type, %__MODULE__{db_ref: db_ref, name: __MODULE__}) do
    _ = Recorder.update_multiread()
    do_get_all_by_type(type, db_ref)
  end

  defp get_all_by_type(type, %__MODULE__{db_ref: db_ref, name: name}) do
    _ = Recorder.update_multiread(name)
    do_get_all_by_type(type, db_ref)
  end

  defp do_get_all_by_type(type, db_ref) do
    db_ref
    |> Exleveldb.stream()
    |> LevelDBCore.filter_keys(type)
    |> Enum.map(fn {_, value} -> {:ok, value} end)
    |> LevelDBCore.decode_values(type)
  end
end
