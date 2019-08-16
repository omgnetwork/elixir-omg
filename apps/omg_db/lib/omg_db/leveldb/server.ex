# Copyright 2019 OmiseGO Pte Ltd
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
  use GenServer

  alias OMG.DB.LevelDB.Core
  require Logger

  defstruct [:db_ref, :name]

  @type t() :: %__MODULE__{
          db_ref: Exleveldb.db_reference(),
          name: GenServer.name()
        }
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

  def start_link([db_path: _db_path, name: name] = args) do
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(db_path: db_path, name: name) do
    # needed so that terminate callback is called on normal close
    Process.flag(:trap_exit, true)
    ^name = create_stats_table(name)

    with {:ok, db_ref} <- Exleveldb.open(db_path, create_if_missing: false) do
      {:ok, _} =
        :timer.send_interval(Application.fetch_env!(:omg_db, :metrics_collection_interval), self(), :send_metrics)

      _ = Logger.info("Started #{inspect(__MODULE__)}")

      {:ok, %__MODULE__{name: name, db_ref: db_ref}}
    else
      error ->
        _ = Logger.error("It seems that #{app()} database is not initialized. Check README.md")
        error
    end
  end

  def handle_info(:send_metrics, state) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, state)
    {:noreply, state}
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

  defp do_multi_update(db_updates, state) do
    result =
      db_updates
      |> Core.parse_multi_updates()
      |> write(state)

    {:reply, result, state}
  end

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

  defp do_exit_infos(state) do
    result = get_all_by_type(:exit_info, state)
    {:reply, result, state}
  end

  defp do_block_hashes(block_numbers_to_fetch, state) do
    result =
      block_numbers_to_fetch
      |> Enum.map(fn block_number -> Core.key(:block_hash, block_number) end)
      |> Enum.map(fn key -> get(key, state) end)
      |> Core.decode_values(:block_hash)

    {:reply, result, state}
  end

  defp do_in_flight_exits_info(state) do
    result = get_all_by_type(:in_flight_exit_info, state)
    {:reply, result, state}
  end

  defp do_competitors_info(state) do
    result = get_all_by_type(:competitor_info, state)
    {:reply, result, state}
  end

  defp do_get_single_value(parameter, state) do
    result =
      parameter
      |> Core.key(nil)
      |> get(state)
      |> Core.decode_value(parameter)

    {:reply, result, state}
  end

  defp do_exit_info(utxo_pos, state) do
    result =
      :exit_info
      |> Core.key(utxo_pos)
      |> get(state)
      |> Core.decode_value(:exit_info)

    {:reply, result, state}
  end

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
  defp write(operations, %__MODULE__{db_ref: db_ref} = state) do
    :ok = :telemetry.execute([:update_write, __MODULE__], %{}, state)
    Exleveldb.write(db_ref, operations)
  end

  @spec get(atom() | binary(), t) :: {:ok, binary()} | :not_found
  defp get(key, %__MODULE__{db_ref: db_ref} = state) do
    :ok = :telemetry.execute([:update_read, __MODULE__], %{}, state)
    Exleveldb.get(db_ref, key)
  end

  defp get_all_by_type(type, %__MODULE__{db_ref: db_ref} = state) do
    :ok = :telemetry.execute([:update_multiread, __MODULE__], %{}, state)
    do_get_all_by_type(type, db_ref)
  end

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

  defp app do
    case Code.ensure_loaded?(OMG.Watcher) do
      true -> :watcher
      _ -> :child_chain
    end
  end

  # WARNING, terminate below will be called only if :trap_exit is set to true
  def terminate(_reason, %__MODULE__{db_ref: db_ref}), do: :ok = Exleveldb.close(db_ref)
end
