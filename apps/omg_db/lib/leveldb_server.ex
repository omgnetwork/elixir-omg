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

  defstruct [:db_ref]

  use GenServer

  alias OMG.DB.LevelDBCore

  require Logger

  def start_link(name: name, db_path: db_path) do
    GenServer.start_link(__MODULE__, %{db_path: db_path}, name: name)
  end

  def init(%{db_path: db_path}) do
    # needed so that terminate callback is called on normal close
    Process.flag(:trap_exit, true)

    with {:ok, db_ref} <- Exleveldb.open(db_path) do
      {:ok, %__MODULE__{db_ref: db_ref}}
    else
      error ->
        _ = Logger.error(fn -> "It seems that Child chain database is not initialized. Check README.md" end)
        error
    end
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

  def handle_call(parameter, _from, %__MODULE__{db_ref: db_ref} = state)
      when is_atom(parameter) do
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
