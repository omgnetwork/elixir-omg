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

defmodule OMG.DB do
  @moduledoc """
  DB API module provides an interface to all needed functions that need to be implemented by the
  underlying database layer.
  """
  use Spandex.Decorators
  @type utxo_pos_db_t :: {pos_integer, non_neg_integer, non_neg_integer}

  @callback start_link(term) :: GenServer.on_start()
  @callback child_spec() :: Supervisor.child_spec()
  @callback child_spec(term) :: Supervisor.child_spec()
  @callback init(String.t()) :: :ok
  @callback init() :: :ok
  @callback initiation_multiupdate() :: :ok | {:error, any}

  @callback multi_update(term()) :: :ok | {:error, any}
  @callback blocks(block_to_fetch :: list()) :: {:ok, list(term)}
  @callback utxos() :: {:ok, list({utxo_pos_db_t, term})}
  @callback utxo(utxo_pos_db_t) :: {:ok, term} | :not_found
  @callback competitors_info() :: {:ok, list(term)}
  @callback spent_blknum(utxo_pos_db_t()) :: {:ok, pos_integer} | :not_found
  @callback block_hashes(integer()) :: {:ok, list()}
  @callback child_top_block_number() :: {:ok, non_neg_integer()} | :not_found
  @callback get_single_value(atom()) :: {:ok, term} | :not_found
  @callback get(atom(), term()) :: {:ok, term} | :not_found
  @callback get_all_by_type(atom()) :: {:ok, list(term)} | :not_found

  # callbacks useful for injecting a specific server implementation
  @callback initiation_multiupdate(GenServer.server()) :: :ok | {:error, any}
  @callback multi_update(term(), GenServer.server()) :: :ok | {:error, any}
  @callback blocks(block_to_fetch :: list(), GenServer.server()) :: {:ok, list()} | {:error, any}
  @callback utxos(GenServer.server()) :: {:ok, list({utxo_pos_db_t, term})} | {:error, any}
  @callback utxo(utxo_pos_db_t, GenServer.server()) :: {:ok, term} | :not_found
  @callback competitors_info(GenServer.server()) :: {:ok, list(term)} | {:error, any}
  @callback spent_blknum(utxo_pos_db_t(), GenServer.server()) :: {:ok, pos_integer} | :not_found
  @callback block_hashes(integer(), GenServer.server()) :: {:ok, list()}
  @callback child_top_block_number(GenServer.server()) :: {:ok, non_neg_integer()} | :not_found
  @callback get_single_value(atom(), GenServer.server()) :: {:ok, term} | :not_found
  @callback get(atom(), term(), GenServer.server()) :: {:ok, term} | :not_found
  @callback get_all_by_type(atom(), GenServer.server()) :: {:ok, list(term)} | :not_found
  @optional_callbacks child_spec: 1,
                      initiation_multiupdate: 1,
                      multi_update: 2,
                      blocks: 2,
                      utxos: 1,
                      utxo: 2,
                      spent_blknum: 2,
                      block_hashes: 2,
                      child_top_block_number: 1,
                      get_single_value: 2

  def start_link(args), do: driver().start_link(args)

  def child_spec(), do: driver().child_spec()
  def child_spec(args), do: driver().child_spec(args)

  def init(path) do
    driver().init(path)
  end

  def init() do
    driver().init()
  end

  @doc """
  Puts all zeroes and other init values to a generically initialized `OMG.DB`
  """

  def initiation_multiupdate(), do: driver().initiation_multiupdate
  def initiation_multiupdate(server), do: driver().initiation_multiupdate(server)

  @decorate span(service: :ethereum_event_listener, type: :backend, name: "multi_update/1")
  def multi_update(db_updates), do: driver().multi_update(db_updates)
  def multi_update(db_updates, server), do: driver().multi_update(db_updates, server)

  def blocks(blocks_to_fetch), do: driver().blocks(blocks_to_fetch)
  def blocks(blocks_to_fetch, server), do: driver().blocks(blocks_to_fetch, server)

  def utxos(), do: driver().utxos()
  def utxos(server), do: driver().utxos(server)

  def utxo(utxo_pos), do: driver().utxo(utxo_pos)
  def utxo(utxo_pos, server), do: driver().utxo(utxo_pos, server)

  def competitors_info(), do: driver().competitors_info
  def competitors_info(server), do: driver().competitors_info(server)

  def spent_blknum(utxo_pos), do: driver().spent_blknum(utxo_pos)
  def spent_blknum(utxo_pos, server), do: driver().spent_blknum(utxo_pos, server)

  def block_hashes(block_numbers_to_fetch), do: driver().block_hashes(block_numbers_to_fetch)
  def block_hashes(block_numbers_to_fetch, server), do: driver().block_hashes(block_numbers_to_fetch, server)

  def child_top_block_number(), do: driver().child_top_block_number

  def get_single_value(parameter_name), do: driver().get_single_value(parameter_name)
  def get_single_value(parameter_name, server), do: driver().get_single_value(parameter_name, server)

  @doc """
  This is generic DB function that can get the specific data of a specific type.
  If it is a single value data, use get_single_value/1 instead.
  """
  def get(type, specific_key), do: driver().get(type, specific_key)
  def get(type, specific_key, server), do: driver().get(type, specific_key, server)

  @doc """
  This is generic DB function that can get all data of a specific type.
  """
  def get_all_by_type(type), do: driver().get_all_by_type(type)
  def get_all_by_type(type, server), do: driver().get_all_by_type(type, server)

  @doc """
  A list of all atoms that we use as single-values stored in the database (i.e. markers/flags of all kinds)
  """
  def single_value_parameter_names() do
    [
      # child chain - used at block forming
      :child_top_block_number,
      # watcher
      :last_block_getter_eth_height,
      # watcher and child chain
      :last_depositor_eth_height,
      :last_exiter_eth_height,
      :last_piggyback_exit_eth_height,
      :last_in_flight_exit_eth_height,
      :last_exit_processor_eth_height,
      :last_exit_finalizer_eth_height,
      :last_exit_challenger_eth_height,
      :last_in_flight_exit_processor_eth_height,
      :last_piggyback_processor_eth_height,
      :last_competitor_processor_eth_height,
      :last_challenges_responds_processor_eth_height,
      :last_piggyback_challenges_processor_eth_height,
      :last_ife_exit_finalizer_eth_height,
      :omg_eth_contracts
    ]
  end

  defp driver(), do: OMG.DB.RocksDB
end
