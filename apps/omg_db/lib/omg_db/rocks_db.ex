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
if Code.ensure_loaded?(:rocksdb) do
  defmodule OMG.DB.RocksDB do
    @moduledoc """
    Our-types-aware port/adapter to a database backend.
    Contains functions to access data stored in the database
    """
    alias OMG.DB
    @behaviour OMG.DB

    require Logger

    @server_name OMG.DB.RocksDB.Server

    @one_minute 60_000
    @ten_minutes 10 * @one_minute

    @type utxo_pos_db_t :: {pos_integer, non_neg_integer, non_neg_integer}

    def start_link(args) do
      @server_name.start_link(args)
    end

    def child_spec do
      db_path = Application.fetch_env!(:omg_db, :path)
      [server_module: server_module, server_name: server_name] = Application.fetch_env!(:omg_db, :rocksdb)
      args = [db_path: db_path, name: server_name]

      %{
        id: server_module,
        start: {server_module, :start_link, [args]},
        type: :worker
      }
    end

    def child_spec([db_path: _db_path, name: server_name] = args) do
      [server_module: server_module, server_name: _] = Application.fetch_env!(:omg_db, :rocksdb)

      %{
        id: server_name,
        start: {server_module, :start_link, [args]},
        type: :worker
      }
    end

    def multi_update(db_updates, server_name \\ @server_name) do
      GenServer.call(server_name, {:multi_update, db_updates})
    end

    @spec blocks(block_to_fetch :: list(), atom) :: {:ok, list()} | {:error, any}
    def blocks(blocks_to_fetch, server_name \\ @server_name)

    def blocks([], _server_name), do: {:ok, []}

    def blocks(blocks_to_fetch, server_name) do
      GenServer.call(server_name, {:blocks, blocks_to_fetch})
    end

    def utxos(server_name \\ @server_name) do
      _ = Logger.info("Reading UTXO set, this might take a while. Allowing #{inspect(@ten_minutes)} ms")
      GenServer.call(server_name, :utxos, @ten_minutes)
    end

    def utxo(utxo_pos, server_name \\ @server_name) do
      GenServer.call(server_name, {:utxo, utxo_pos})
    end

    def exit_infos(server_name \\ @server_name) do
      _ = Logger.info("Reading exits' info, this might take a while. Allowing #{inspect(@one_minute)} ms")
      GenServer.call(server_name, :exit_infos, @one_minute)
    end

    def in_flight_exits_info(server_name \\ @server_name) do
      _ = Logger.info("Reading in flight exits' info, this might take a while. Allowing #{inspect(@one_minute)} ms")
      GenServer.call(server_name, :in_flight_exits_info, @one_minute)
    end

    def competitors_info(server_name \\ @server_name) do
      _ = Logger.info("Reading competitors' info, this might take a while. Allowing #{inspect(@one_minute)} ms")
      GenServer.call(server_name, :competitors_info, @one_minute)
    end

    def exit_info(utxo_pos, server_name \\ @server_name) do
      GenServer.call(server_name, {:exit_info, utxo_pos})
    end

    def spent_blknum(utxo_pos, server_name \\ @server_name) do
      GenServer.call(server_name, {:spent_blknum, utxo_pos})
    end

    def block_hashes(block_numbers_to_fetch, server_name \\ @server_name) do
      GenServer.call(server_name, {:block_hashes, block_numbers_to_fetch})
    end

    def child_top_block_number(server_name \\ @server_name) do
      GenServer.call(server_name, :child_top_block_number)
    end

    # Note: *_eth_height values below denote actual Ethereum height service has processed.
    # It might differ from "latest" Ethereum block.

    def get_single_value(parameter_name, server_name \\ @server_name) do
      GenServer.call(server_name, {:get_single_value, parameter_name})
    end

    def initiation_multiupdate(server_name \\ @server_name) do
      # setting a number of markers to zeroes
      DB.single_value_parameter_names()
      |> Enum.map(&{:put, &1, 0})
      |> multi_update(server_name)
    end

    @doc """
    Does all of the initialization of `OMG.DB` based on the configured path
    """
    def init, do: do_init(@server_name, Application.fetch_env!(:omg_db, :path))
    def init(path) when is_binary(path), do: do_init(@server_name, path)
    def init(server_name), do: do_init(server_name, Application.fetch_env!(:omg_db, :path))
    def init(server_name, path), do: do_init(server_name, path)

    # File.mkdir_p is called at the application start
    # sobelow_skip ["Traversal"]
    defp do_init(server_name, path) do
      :ok = File.mkdir_p(path)

      with :ok <- server_name.init_storage(path),
           {:ok, started_apps} <- Application.ensure_all_started(:omg_db),
           :ok <- initiation_multiupdate(server_name) do
        started_apps |> Enum.reverse() |> Enum.each(fn app -> :ok = Application.stop(app) end)

        :ok
      else
        error ->
          _ = Logger.error("Unable to init: #{inspect(error)}")
          error
      end
    end
  end
end
