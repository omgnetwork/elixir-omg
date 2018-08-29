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

defmodule OMG.DB do
  @moduledoc """
  Our-types-aware port/adapter to the db backend.
  Call these functions to access the data stored in the database
  """

  ### Client (port)

  require Logger

  @server_name OMG.DB.LevelDBServer

  def multi_update(db_updates, server_name \\ @server_name) do
    {duration, result} = :timer.tc(fn -> GenServer.call(server_name, {:multi_update, db_updates}) end)
    _ = Logger.debug(fn -> "DB.multi_update done in #{inspect(round(duration / 1000))} ms" end)
    result
  end

  @spec blocks(block_to_fetch :: list()) :: {:ok, list()} | {:error, any}
  def blocks(blocks_to_fetch, server_name \\ @server_name) do
    GenServer.call(server_name, {:blocks, blocks_to_fetch})
  end

  def utxos(server_name \\ @server_name) do
    GenServer.call(server_name, {:utxos})
  end

  def block_hashes(block_numbers_to_fetch, server_name \\ @server_name) do
    GenServer.call(server_name, {:block_hashes, block_numbers_to_fetch})
  end

  def last_deposit_height(server_name \\ @server_name) do
    GenServer.call(server_name, :last_deposit_block_height)
  end

  def child_top_block_number(server_name \\ @server_name) do
    GenServer.call(server_name, :child_top_block_number)
  end

  def last_fast_exit_block_height(server_name \\ @server_name) do
    GenServer.call(server_name, :last_fast_exit_block_height)
  end

  def last_slow_exit_block_height(server_name \\ @server_name) do
    GenServer.call(server_name, :last_slow_exit_block_height)
  end

  def last_block_getter_block_height(server_name \\ @server_name) do
    GenServer.call(server_name, :last_block_getter_synced_height)
  end

  def init do
    path = Application.get_env(:omg_db, :leveldb_path)
    :ok = File.mkdir_p(path)

    if Enum.empty?(File.ls!(path)) do
      {:ok, started_apps} = Application.ensure_all_started(:omg_db)

      :ok =
        OMG.DB.multi_update([
          {:put, :last_deposit_block_height, 0},
          {:put, :last_fast_exit_block_height, 0},
          {:put, :last_slow_exit_block_height, 0},
          {:put, :child_top_block_number, 0},
          {:put, :last_block_getter_synced_height, 0}
        ])

      started_apps |> Enum.reverse() |> Enum.each(fn app -> :ok = Application.stop(app) end)

      :ok
    else
      {:error, :folder_not_empty}
    end
  end
end
