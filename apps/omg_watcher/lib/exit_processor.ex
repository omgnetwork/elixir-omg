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

defmodule OMG.Watcher.ExitProcessor do
  @moduledoc """
  Encapsulates managing and executing the behaviors related to treating exits by the child chain and watchers
  Keeps a state of exits that are in progress, updates it with news from the root chain, compares to the
  state of the ledger (`OMG.API.State`), issues notifications as it finds suitable.

  Should manage all kinds of exits allowed in the protocol and handle the interactions between them.
  """

  alias OMG.API.EventerAPI
  alias OMG.API.State
  alias OMG.DB
  alias OMG.Eth
  alias OMG.Watcher.ExitProcessor.Core

  use OMG.API.LoggerExt

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Accepts events and processes them in the state - new exits are tracked.
  Returns `db_updates` due and relies on the caller to do persistence
  """
  def new_exits(exits) do
    GenServer.call(__MODULE__, {:new_exits, exits})
  end

  @doc """
  Accepts events and processes them in the state - finalized exits are untracked _if valid_ otherwise raises alert
  Returns `db_updates` due and relies on the caller to do persistence
  """
  def finalize_exits(exits) do
    GenServer.call(__MODULE__, {:finalize_exits, exits})
  end

  @doc """
  Accepts events and processes them in the state - challenged exits are untracked
  Returns `db_updates` due and relies on the caller to do persistence
  """
  def challenge_exits(exits) do
    GenServer.call(__MODULE__, {:challenge_exits, exits})
  end

  @doc """
  Checks validity and causes event emission to `OMG.Watcher.Eventer`. Works with `OMG.API.State` to discern validity
  """
  def check_validity do
    GenServer.call(__MODULE__, :check_validity)
  end

  ### Server

  use GenServer

  def init(:ok) do
    {:ok, db_exits} = DB.exit_infos()

    sla_margin = Application.fetch_env!(:omg_watcher, :margin_slow_validator)
    interval = Application.fetch_env!(:omg_watcher, :exit_processor_validation_interval_ms)

    {:ok, _} = :timer.send_interval(interval, self(), :check_validity)

    Core.init(db_exits, sla_margin)
  end

  def handle_call({:new_exits, exits}, _from, state) do
    exit_contract_statuses =
      Enum.map(exits, fn %{utxo_pos: utxo_pos} ->
        {:ok, result} = Eth.RootChain.get_exit(utxo_pos)
        result
      end)

    {new_state, db_updates} = Core.new_exits(state, exits, exit_contract_statuses)
    _ = OMG.Watcher.DB.EthEvent.insert_exits(exits)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:finalize_exits, exits}, _from, state) do
    {:ok, db_updates_from_state, validities} = State.exit_utxos(exits)

    {new_state, db_updates} = Core.finalize_exits(state, validities)

    {:reply, {:ok, db_updates ++ db_updates_from_state}, new_state}
  end

  def handle_call({:challenge_exits, exits}, _from, state) do
    {new_state, db_updates} = Core.challenge_exits(state, exits)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call(:check_validity, _from, state) do
    chain_status = check_validity(state)

    {:reply, chain_status, state}
  end

  def handle_info(:check_validity, state) do
    _ = check_validity(state)
    {:noreply, state}
  end

  defp check_validity(state) do
    {event_triggers, chain_status} = determine_invalid_exits(state)

    EventerAPI.emit_events(event_triggers)

    chain_status
  end

  # combine data from `ExitProcessor` and `API.State` to figure out what to do about exits
  defp determine_invalid_exits(state) do
    {:ok, eth_height_now} = Eth.get_ethereum_height()

    state
    |> Core.get_exiting_utxo_positions()
    |> Enum.map(&State.utxo_exists?/1)
    |> Core.invalid_exits(state, eth_height_now)
  end
end
