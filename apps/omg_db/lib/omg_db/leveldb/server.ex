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

defmodule OMG.DB.LevelDB.Server do
  @moduledoc """
  Handles connection to leveldb
  """

  # All complex operations on data written/read should go into OMG.DB.LevelDB.Core
  use OMG.Utils.Metrics
  use GenServer

  alias OMG.DB.LevelDB.Core
  alias OMG.DB.LevelDB.Recorder
  require Logger

  defstruct [:db_ref, :name]

  @type t() :: %__MODULE__{
          db_ref: Exleveldb.db_reference(),
          name: GenServer.name()
        }

  def start_link([db_path: _db_path, name: name] = args) do
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(db_path: db_path, name: name) do
    # needed so that terminate callback is called on normal close
    Process.flag(:trap_exit, true)
    table = create_stats_table(name)

    recorder_name =
      name
      |> Atom.to_string()
      |> Kernel.<>(".Recorder")
      |> String.to_atom()

    {:ok, _recorder_pid} = Recorder.start_link(%Recorder{name: recorder_name, parent: self(), table: table})

    with {:ok, db_ref} <- Exleveldb.open(db_path, create_if_missing: false) do
      {:ok, %__MODULE__{name: name, db_ref: db_ref}}
    else
      error ->
        _ = Logger.error("It seems that Child chain database is not initialized. Check README.md")
        error
    end
  end

  def handle_call({:multi_update, db_updates}, _from, state), do: do_multi_update(db_updates, state)
  def handle_call({:blocks, blocks_to_fetch}, _from, state), do: do_blocks(blocks_to_fetch, state)
  def handle_call(:utxos, _from, state), do: do_utxos(state)
  def handle_call(:exit_infos, _from, state), do: do_exit_infos(state)

  def handle_call({:block_hashes, block_numbers_to_fetch}, _from, state),
    do: do_block_hashes(block_numbers_to_fetch, state)

  def handle_call(:in_flight_exits_info, _from, state), do: do_in_flight_exits_info(state)
  def handle_call(:competitors_info, _from, state), do: do_competitors_info(state)

  def handle_call({:get_single_value, parameter}, _from, state)
      when is_atom(parameter),
      do: do_get_single_value(parameter, state)

  def handle_call({:exit_info, utxo_pos}, _from, state), do: do_exit_info(utxo_pos, state)
  def handle_call({:spent_blknum, utxo_pos}, _from, state), do: do_spent_blknum(utxo_pos, state)

  @decorate measure_event()
  defp do_multi_update(db_updates, state) do
    result =
      db_updates
      |> Core.parse_multi_updates()
      |> write(state)

    {:reply, result, state}
  end

  @decorate measure_event()
  defp do_blocks(blocks_to_fetch, state) do
    result =
      blocks_to_fetch
      |> Enum.map(fn block -> Core.key(:block, block) end)
      |> Enum.map(fn key -> get(key, state) end)
      |> Core.decode_values(:block)

    {:reply, result, state}
  end

  defp do_utxos(state) do
    result = get_all_by_type(:utxo, state)
    {:reply, result, state}
  end

  @decorate measure_event()
  defp do_exit_infos(state) do
    result = get_all_by_type(:exit_info, state)
    {:reply, result, state}
  end

  @decorate measure_event()
  defp do_block_hashes(block_numbers_to_fetch, state) do
    result =
      block_numbers_to_fetch
      |> Enum.map(fn block_number -> Core.key(:block_hash, block_number) end)
      |> Enum.map(fn key -> get(key, state) end)
      |> Core.decode_values(:block_hash)

    {:reply, result, state}
  end

  @decorate measure_event()
  defp do_in_flight_exits_info(state) do
    result = get_all_by_type(:in_flight_exit_info, state)
    {:reply, result, state}
  end

  @decorate measure_event()
  defp do_competitors_info(state) do
    result = get_all_by_type(:competitor_info, state)
    {:reply, result, state}
  end

  @decorate measure_event()
  defp do_get_single_value(parameter, state) do
    result =
      parameter
      |> Core.key(nil)
      |> get(state)
      |> Core.decode_value(parameter)

    {:reply, result, state}
  end

  @decorate measure_event()
  defp do_exit_info(utxo_pos, state) do
    result =
      :exit_info
      |> Core.key(utxo_pos)
      |> get(state)
      |> Core.decode_value(:exit_info)

    {:reply, result, state}
  end

  @decorate measure_event()
  defp do_spent_blknum(utxo_pos, state) do
    result =
      :spend
      |> Core.key(utxo_pos)
      |> get(state)
      |> Core.decode_value(:spend)

    {:reply, result, state}
  end

  # Argument order flipping tools :(
  @spec write(Exleveldb.write_actions(), t) :: :ok | {:error, any}
  defp write(operations, %__MODULE__{db_ref: db_ref, name: name}) do
    _ = Recorder.update_write(name)
    Exleveldb.write(db_ref, operations)
  end

  @spec get(atom() | binary(), t) :: {:ok, binary()} | :not_found
  defp get(key, %__MODULE__{db_ref: db_ref, name: name}) do
    _ = Recorder.update_read(name)
    Exleveldb.get(db_ref, key)
  end

  @decorate measure_event()
  defp get_all_by_type(type, %__MODULE__{db_ref: db_ref, name: name}) do
    _ = Recorder.update_multiread(name)
    do_get_all_by_type(type, db_ref)
  end

  @decorate measure_event()
  defp do_get_all_by_type(type, db_ref) do
    db_ref
    |> Exleveldb.stream()
    |> Core.filter_keys(type)
    |> Enum.map(fn {_, value} -> {:ok, value} end)
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

  # WARNING, terminate below will be called only if :trap_exit is set to true
  def terminate(_reason, %__MODULE__{db_ref: db_ref}) do
    :ok = Exleveldb.close(db_ref)
  end
end
