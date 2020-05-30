# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.DB.RocksDB do
  @moduledoc """
  Our-types-aware port/adapter to a database backend.
  Contains functions to access data stored in the database
  """
  alias OMG.DB
  @behaviour OMG.DB

  require Logger

  @server_name OMG.DB.RocksDB.Server

  @default_genserver_timeout 5000
  @one_minute 60_000
  @ten_minutes 10 * @one_minute

  @type utxo_pos_db_t :: {pos_integer, non_neg_integer, non_neg_integer}

  def start_link(args) do
    @server_name.start_link(args)
  end

  def child_spec() do
    db_path = Application.fetch_env!(:omg_db, :path)
    args = [db_path: db_path, name: OMG.DB.RocksDB.Server]

    %{
      id: OMG.DB.RocksDB.Server,
      start: {OMG.DB.RocksDB.Server, :start_link, [args]},
      type: :worker
    }
  end

  def child_spec([db_path: _db_path, name: server_name] = args) do
    %{
      id: server_name,
      start: {OMG.DB.RocksDB.Server, :start_link, [args]},
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

  def competitors_info(server_name \\ @server_name) do
    _ = Logger.info("Reading competitors' info, this might take a while. Allowing #{inspect(@one_minute)} ms")
    GenServer.call(server_name, :competitors_info, @one_minute)
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

  @doc """
  Batch get data of a type with the given specific keys.

  optional args includes:
  1. timeout (in ms). Defaults to 5000 which is the same default value of Genserver.
  2. server (type in Genserver.server()). Defaults to Defaults to OMG.DB.RocksDB.Server.
  """
  def batch_get(type, specific_keys, opts \\ []) do
    timeout = opts[:timeout] || @default_genserver_timeout
    server = opts[:server] || @server_name

    _ =
      Logger.info(
        "Batch get data for type #{inspect(type)} with the following keys #{inspect(specific_keys)}." <>
          " Allowing #{inspect(timeout)} ms"
      )

    GenServer.call(server, {:get, type, specific_keys}, timeout)
  end

  @doc """
  Get ALL data of a type.

  optional args includes:
  1. timeout (in ms). Defaults to 5000 which is the same default value of Genserver.
  2. server (type in Genserver.server()). Defaults to OMG.DB.RocksDB.Server.
  """
  def get_all_by_type(type, opts \\ []) do
    timeout = opts[:timeout] || @default_genserver_timeout
    server = opts[:server] || @server_name

    _ =
      Logger.info(
        "Reading all data for type #{inspect(type)}, this might take a while. Allowing #{inspect(timeout)} ms"
      )

    GenServer.call(server, {:get_all_by_type, type}, timeout)
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
  def init(), do: do_init(@server_name, Application.fetch_env!(:omg_db, :path))

  def init(path) when is_binary(path) do
    :ok = Application.put_env(:omg_db, :path, path, persistent: true)
    do_init(@server_name, path)
  end

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
