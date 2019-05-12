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

defmodule OMG.DB.RocksDB.Worker do
  @moduledoc """
  Handles connection to leveldb
  """

  # All complex operations on data written/read should go into OMG.DB.RocksDB.Core

  use GenServer
  alias OMG.DB.RocksDB.Core
  alias OMG.DB.RocksDB.Recorder
  require Logger

  defstruct [:db_ref, :name]

  @type t() :: %__MODULE__{
          db_ref: :rocksdb.db_handle(),
          name: GenServer.name()
        }

  def start_link([db_path: _db_path, name: name] = args) do
    GenServer.start_link(__MODULE__, args, name: name)
  end

  # https://github.com/facebook/rocksdb/wiki/RocksDB-Tuning-Guide#prefix-databases
  def init(db_path: db_path, name: name) do
    # needed so that terminate callback is called on normal close
    db_path = String.to_charlist(db_path)
    Process.flag(:trap_exit, true)
    table = create_stats_table(name)

    recorder_name =
      name
      |> Atom.to_string()
      |> Kernel.<>(".Recorder")
      |> String.to_atom()

    {:ok, _recorder_pid} = Recorder.start_link(%Recorder{name: recorder_name, parent: self(), table: table})
    setup = [{:create_if_missing, true}, {:prefix_extractor, {:fixed_prefix_transform, 1}}]

    with {:ok, db_ref} <- :rocksdb.open(db_path, setup) do
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
      |> Core.parse_multi_updates()
      |> write(state)

    {:reply, result, state}
  end

  def handle_call({:blocks, blocks_to_fetch}, _from, state) do
    result =
      blocks_to_fetch
      |> Enum.map(fn block -> Core.key(:block, block) end)
      |> Enum.map(fn key -> get(key, state) end)
      |> Core.decode_values(:block)

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
      |> Enum.map(fn block_number -> Core.key(:block_hash, block_number) end)
      |> Enum.map(fn key -> get(key, state) end)
      |> Core.decode_values(:block_hash)

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
      |> Core.key(nil)
      |> get(state)
      |> Core.decode_value(parameter)

    {:reply, result, state}
  end

  def handle_call({:exit_info, utxo_pos}, _from, state) do
    result =
      :exit_info
      |> Core.key(utxo_pos)
      |> get(state)
      |> Core.decode_value(:exit_info)

    {:reply, result, state}
  end

  def handle_call({:spent_blknum, utxo_pos}, _from, state) do
    result =
      :spend
      |> Core.key(utxo_pos)
      |> get(state)
      |> Core.decode_value(:spend)

    {:reply, result, state}
  end

  # WARNING, terminate below will be called only if :trap_exit is set to true
  def terminate(_reason, %__MODULE__{db_ref: db_ref}) do
    :ok = :rocksdb.close(db_ref)
  end

  # Argument order flipping tools :(
  # write options
  # write_options() = [{sync, boolean()} | {disable_wal, boolean()} | {ignore_missing_column_families, boolean()} |
  # {no_slowdown, boolean()} | {low_pri, boolean()}]
  # @spec write(Exleveldb.write_actions(), t) :: :ok | {:error, any}
  defp write(operations, %__MODULE__{db_ref: db_ref, name: name}) do
    _ = Recorder.update_write(name)
    :rocksdb.write(db_ref, operations, [])
  end

  # get read options
  # read_options() = [{verify_checksums, boolean()} | {fill_cache, boolean()} | {iterate_upper_bound, binary()} |
  # {iterate_lower_bound, binary()} | {tailing, boolean()} | {total_order_seek, boolean()} |
  # {prefix_same_as_start, boolean()} | {snapshot, snapshot_handle()}]
  @spec get(atom() | binary(), t) :: {:ok, binary()} | :not_found
  defp get(key, %__MODULE__{db_ref: db_ref, name: name}) do
    _ = Recorder.update_read(name)
    :rocksdb.get(db_ref, key, [])
  end

  defp get_all_by_type(type, %__MODULE__{db_ref: db_ref, name: name}) do
    _ = Recorder.update_multiread(name)
    do_get_all_by_type(type, db_ref)
  end

  # iterator options
  # same as read options
  # this might be a use case for seek() https://github.com/facebook/rocksdb/wiki/Prefix-Seek-API-Changes
  defp do_get_all_by_type(type, db_ref) do
    Core.filter_keys(db_ref, type)
    |> Core.decode_values(type)
  end

  defp create_stats_table(name) do
    case :ets.whereis(name) do
      :undefined ->
        true = name == :ets.new(name, table_settings())

        name

      _ ->
        name
    end
  end

  defp table_settings, do: [:named_table, :set, :public, write_concurrency: true]
end
