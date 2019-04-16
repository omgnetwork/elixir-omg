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

  @type utxo_pos_db_t :: {pos_integer, non_neg_integer, non_neg_integer}

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

  @spec spent_blknum(utxo_pos_db_t(), atom) :: {:ok, pos_integer} | {:error, atom}
  def spent_blknum(utxo_pos, server_name \\ @server_name) do
    GenServer.call(server_name, {:spent_blknum, utxo_pos})
  end

  def block_hashes(block_numbers_to_fetch, server_name \\ @server_name) do
    GenServer.call(server_name, {:block_hashes, block_numbers_to_fetch})
  end

  # Note: *_eth_height values below denote actual Ethereum height service has processed.
  # It might differ from "latest" Ethereum block.

  def get_single_value(server_name \\ @server_name, parameter_name) do
    GenServer.call(server_name, {:get_single_value, parameter_name})
  end
end
