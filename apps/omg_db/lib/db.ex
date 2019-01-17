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
  Our-types-aware port/adapter to a database backend.
  Contains functions to access data stored in the database
  """

  ### Client (port)

  require Logger

  @server_name OMG.DB.LevelDBServer

  @one_minute 60_000
  @ten_minutes 10 * @one_minute

  def multi_update(db_updates, server_name \\ @server_name) do
    {duration, result} = :timer.tc(fn -> GenServer.call(server_name, {:multi_update, db_updates}) end)
    _ = Logger.debug(fn -> "DB.multi_update done in #{inspect(round(duration / 1000))} ms" end)
    result
  end

  @spec blocks(block_to_fetch :: list(), atom) :: {:ok, list()} | {:error, any}
  def blocks(blocks_to_fetch, server_name \\ @server_name)

  def blocks([], _server_name), do: {:ok, []}

  def blocks(blocks_to_fetch, server_name) do
    GenServer.call(server_name, {:blocks, blocks_to_fetch})
  end

  def utxos(server_name \\ @server_name) do
    _ = Logger.info(fn -> "Reading UTXO set, this might take a while. Allowing #{inspect(@ten_minutes)} ms" end)
    GenServer.call(server_name, :utxos, @ten_minutes)
  end

  def exit_infos(server_name \\ @server_name) do
    _ = Logger.info(fn -> "Reading exits' info, this might take a while. Allowing #{inspect(@one_minute)} ms" end)
    GenServer.call(server_name, :exit_infos, @one_minute)
  end

  def in_flight_exits_info(server_name \\ @server_name) do
    _ =
      Logger.info(fn ->
        "Reading in flight exits' info, this might take a while. Allowing #{inspect(@one_minute)} ms"
      end)

    GenServer.call(server_name, :in_flight_exits_info, @one_minute)
  end

  def competitors_info(server_name \\ @server_name) do
    _ =
      Logger.info(fn ->
        "Reading competitors' info, this might take a while. Allowing #{inspect(@one_minute)} ms"
      end)

    GenServer.call(server_name, :competitors_info, @one_minute)
  end

  @spec spent_blknum({pos_integer, non_neg_integer, non_neg_integer}, atom) :: {:ok, pos_integer} | {:error, atom}
  def spent_blknum(utxo_pos, server_name \\ @server_name) do
    GenServer.call(server_name, {:spent_blknum, utxo_pos})
  end

  def block_hashes(block_numbers_to_fetch, server_name \\ @server_name) do
    GenServer.call(server_name, {:block_hashes, block_numbers_to_fetch})
  end

  def last_deposit_child_blknum(server_name \\ @server_name) do
    GenServer.call(server_name, :last_deposit_child_blknum)
  end

  def child_top_block_number(server_name \\ @server_name) do
    GenServer.call(server_name, :child_top_block_number)
  end

  # Note: *_eth_height values below denote actual Ethereum height service has processed.
  # It might differ from "latest" Ethereum block.

  def last_block_getter_eth_height(server_name \\ @server_name) do
    GenServer.call(server_name, :last_block_getter_eth_height)
  end

  def last_depositor_eth_height(server_name \\ @server_name) do
    GenServer.call(server_name, :last_depositor_eth_height)
  end

  def last_in_flight_exit_eth_height(server_name \\ @server_name) do
    GenServer.call(server_name, :last_in_flight_exit_eth_height)
  end

  def last_piggyback_exit_eth_height(server_name \\ @server_name) do
    GenServer.call(server_name, :last_piggyback_exit_eth_height)
  end

  def last_exiter_eth_height(server_name \\ @server_name) do
    GenServer.call(server_name, :last_exiter_eth_height)
  end

  def last_exit_processor_eth_height(server_name \\ @server_name) do
    GenServer.call(server_name, :last_exit_processor_eth_height)
  end

  def last_exit_finalizer_eth_height(server_name \\ @server_name) do
    GenServer.call(server_name, :last_exit_finalizer_eth_height)
  end

  def last_exit_challenger_eth_height(server_name \\ @server_name) do
    GenServer.call(server_name, :last_exit_challenger_eth_height)
  end

  def init(server_name \\ @server_name) do
    path = Application.fetch_env!(:omg_db, :leveldb_path)
    :ok = File.mkdir_p(path)

    db_initialization_updates = [
      {:put, :last_deposit_child_blknum, 0},
      {:put, :child_top_block_number, 0},
      {:put, :last_block_getter_eth_height, 0},
      {:put, :last_depositor_eth_height, 0},
      {:put, :last_exiter_eth_height, 0},
      {:put, :last_exit_processor_eth_height, 0},
      {:put, :last_exit_finalizer_eth_height, 0},
      {:put, :last_exit_challenger_eth_height, 0},
      {:put, :last_piggyback_exit_eth_height, 0},
      {:put, :last_in_flight_exit_eth_height, 0}
    ]

    with :ok <- server_name.init_storage(path),
         {:ok, started_apps} <- Application.ensure_all_started(:omg_db),
         :ok <- OMG.DB.multi_update(db_initialization_updates) do
      started_apps |> Enum.reverse() |> Enum.each(fn app -> :ok = Application.stop(app) end)

      :ok
    else
      error ->
        _ = Logger.error(fn -> "Unable to init: #{inspect(error)}" end)
        error
    end
  end
end
