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

  NOTE: Note that all calls return `db_updates` and relay on the caller to do persistence.
  """

  alias OMG.API.State
  alias OMG.DB
  alias OMG.Eth
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo

  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Accepts events and processes them in the state - new exits are tracked.
  Returns `db_updates`
  """
  def new_exits(exits) do
    GenServer.call(__MODULE__, {:new_exits, exits})
  end

  @doc """
  Accepts events and processes them in the state - new in flight exits are tracked.
  Returns `db_updates`
  """
  def new_in_flight_exits(in_flight_exit_started_events) do
    GenServer.call(__MODULE__, {:new_in_flight_exits, in_flight_exit_started_events})
  end

  @doc """
  Accepts events and processes them in the state - finalized exits are untracked _if valid_ otherwise raises alert
  Returns `db_updates`
  """
  def finalize_exits(finalizations) do
    GenServer.call(__MODULE__, {:finalize_exits, finalizations})
  end

  @doc """
  Accepts events and processes them in the state - new piggybacks are tracked, if invalid raises an alert
  Returns `db_updates`
  """
  def piggyback_exits(piggybacks) do
    GenServer.call(__MODULE__, {:piggyback_exits, piggybacks})
  end

  @doc """
  Accepts events and processes them in the state - challenged exits are untracked
  Returns `db_updates`
  """
  def challenge_exits(challenges) do
    GenServer.call(__MODULE__, {:challenge_exits, challenges})
  end

  @doc """
  Accepts events and processes them in the state.
  Competitors are stored for future use(i.e. to challenge an in flight exit).
  Returns `db_updates`
  """
  def challenge_in_flight_exits(challenges) do
    GenServer.call(__MODULE__, {:challenge_in_flight_exits, challenges})
  end

  @doc """
  Accepts events and processes them in state.
  Returns `db_updates`
  """
  def respond_to_in_flight_exits_challenges(responds) do
    GenServer.call(__MODULE__, {:respond_to_in_flight_exits_challenges, responds})
  end

  @doc """
  Accepts events and processes them in state.
  Challenged piggybacks are forgotten.
  Returns `db_updates`
  """
  def challenge_piggybacks(challenges) do
    GenServer.call(__MODULE__, {:challenge_piggybacks, challenges})
  end

  @doc """
    Accepts events and processes them in state - finalized outputs are applied to the state.
    Returns `db_updates`
  """
  def finalize_in_flight_exits(finalizations) do
    GenServer.call(__MODULE__, {:finalize_in_flight_exits, finalizations})
  end

  @doc """
  Checks validity and causes event emission to `OMG.Watcher.Eventer`. Works with `OMG.API.State` to discern validity
  """
  def check_validity do
    GenServer.call(__MODULE__, :check_validity)
  end

  @doc """
  Returns a map of requested in flight exits, where keys are IFE hashes and values are IFES
  If given empty list of hashes, all IFEs are returned.
  """
  @spec get_in_flight_exits([binary()]) :: %{binary() => InFlightExitInfo.t()}
  def get_in_flight_exits(hashes \\ []) do
    GenServer.call(__MODULE__, {:get_ifes, hashes})
  end

  ### Server

  use GenServer

  def init(:ok) do
    {:ok, db_exits} = DB.exit_infos()
    {:ok, db_ifes} = DB.in_flight_exits_info()
    {:ok, db_competitors} = DB.competitors_info()

    sla_margin = Application.fetch_env!(:omg_watcher, :exit_processor_sla_margin)

    Core.init(db_exits, db_ifes, db_competitors, sla_margin)
  end

  def handle_call({:new_exits, exits}, _from, state) do
    exit_contract_statuses =
      Enum.map(
        exits,
        fn %{utxo_pos: utxo_pos} ->
          {:ok, exit_id} = Eth.RootChain.get_standard_exit_id(utxo_pos)
          {:ok, result} = Eth.RootChain.get_exit(exit_id)
          result
        end
      )

    {new_state, db_updates} = Core.new_exits(state, exits, exit_contract_statuses)
    _ = OMG.Watcher.DB.EthEvent.insert_exits(exits)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:new_in_flight_exits, events}, _from, state) do
    ife_contract_statuses =
      Enum.map(
        events,
        fn %{tx_bytes: bytes} ->
          {:ok, contract_ife_id} = Eth.RootChain.get_in_flight_exit_id(bytes)
          {:ok, {timestamp, _, _, _}} = Eth.RootChain.get_in_flight_exit(contract_ife_id)
          {timestamp, contract_ife_id}
        end
      )

    {new_state, db_updates} = Core.new_in_flight_exits(state, events, ife_contract_statuses)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:finalize_exits, exits}, _from, state) do
    {:ok, db_updates_from_state, validities} = State.exit_utxos(exits)

    {new_state, db_updates} = Core.finalize_exits(state, validities)

    {:reply, {:ok, db_updates ++ db_updates_from_state}, new_state}
  end

  def handle_call({:piggyback_exits, exits}, _from, state) do
    {new_state, db_updates} = Core.new_piggybacks(state, exits)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:challenge_exits, exits}, _from, state) do
    {new_state, db_updates} = Core.challenge_exits(state, exits)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:challenge_in_flight_exits, challenges}, _from, state) do
    {new_state, db_updates} = Core.challenge_in_flight_exits(state, challenges)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:challenge_piggybacks, challenges}, _from, state) do
    {new_state, db_updates} = Core.challenge_piggybacks(state, challenges)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:respond_to_in_flight_exits_challenges, responds}, _from, state) do
    {new_state, db_updates} = Core.respond_to_in_flight_exits_challenges(state, responds)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call({:finalize_in_flight_exits, finalizations}, _from, state) do
    {new_state, db_updates} = Core.finalize_in_flight_exits(state, finalizations)
    {:reply, {:ok, db_updates}, new_state}
  end

  def handle_call(:check_validity, _from, state) do
    {chain_status, events} = determine_invalid_exits(state)

    {:reply, {chain_status, events}, state}
  end

  def handle_call({:get_ifes, hashes}, _from, state),
    do: {:reply, Core.get_in_flight_exits(hashes), state}

  # combine data from `ExitProcessor` and `API.State` to figure out what to do about exits
  defp determine_invalid_exits(state) do
    {:ok, eth_height_now} = Eth.get_ethereum_height()
    {blknum_now, _} = State.get_status()

    state
    |> Core.get_exiting_utxo_positions()
    |> Enum.map(&State.utxo_exists?/1)
    |> Core.invalid_exits(state, eth_height_now, blknum_now)
  end
end
