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

defmodule OMG.API.ExitProcessor.Core do
  @moduledoc """
  The functional, zero-side-effect part of the exit processor. Logic should go here:
    - orchestrating the persistence of the state
    - finding invalid exits, disseminating them as events according to rules
    - MoreVP protocol managing should go here
  """

  alias OMG.API.Crypto
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Watcher.Eventer.Event

  use OMG.API.LoggerExt

  @default_sla_margin 10
  @zero_address Crypto.zero_address()

  defstruct [:sla_margin, exits: %{}]

  @type t :: %__MODULE__{exits: map}

  @doc """
  Reads database-specific list of exits and turns them into current state
  """
  @spec init(db_exits :: [{Utxo.Position.t(), map}]) :: {:ok, t()}
  def init(db_exits, sla_margin \\ @default_sla_margin) do
    {:ok,
     %__MODULE__{
       exits: Map.new(db_exits),
       sla_margin: sla_margin
     }}
  end

  @doc """
  Add new exits from Ethereum events into tracked state.

  The list of `exit_contract_statuses` is used to track current (as in wall-clock "now", not syncing "now") status.
  This is to prevent spurrious invalid exit events being fired during syncing for exits that were challenged/finalized
  Still we do want to track these exits when syncing, to have them spend from `OMG.API.State` on their finalization
  """
  @spec new_exits(t(), [map()], list(map)) :: {t(), list()}
  def new_exits(%__MODULE__{exits: exits} = state, new_exits, exit_contract_statuses) do
    new_exits_kv_pairs =
      new_exits
      |> Enum.zip(exit_contract_statuses)
      |> Enum.map(fn {%{utxo_pos: utxo_pos} = exit_info, contract_status} ->
        is_active = parse_contract_status(contract_status)
        {Utxo.Position.decode(utxo_pos), Map.delete(exit_info, :utxo_pos) |> Map.put(:is_active, is_active)}
      end)

    db_updates =
      new_exits_kv_pairs
      |> Enum.map(fn {utxo_pos, exit_info} -> {:put, :exit_info, {utxo_pos, exit_info}} end)

    new_exits_map = Map.new(new_exits_kv_pairs)

    {%{state | exits: Map.merge(exits, new_exits_map)}, db_updates}
  end

  defp parse_contract_status({@zero_address, _contract_token, _contract_amount}), do: false
  defp parse_contract_status({_contract_owner, _contract_token, _contract_amount}), do: true

  @doc """
  Finalize exits based on Ethereum events, removing from tracked state.
  """
  @spec finalize_exits(t(), list(map)) :: {t(), list, list}
  def finalize_exits(%__MODULE__{} = state, exits) do
    # NOTE: We don't need to deactivate these exits, as they're forgotten forever here
    #       Also exits marked as `is_active` still finalize just the same
    finalizing_positions =
      exits
      |> Enum.map(fn %{utxo_pos: utxo_pos} = _finalization_info -> Utxo.Position.decode(utxo_pos) end)

    db_updates =
      finalizing_positions
      |> Enum.map(fn utxo_pos -> {:delete, :exit_info, utxo_pos} end)

    {state, db_updates, finalizing_positions}
  end

  @spec challenge_exits(t(), list(map)) :: {t(), list}
  def challenge_exits(%__MODULE__{} = state, _exits) do
    # NOTE: we don't need to deactivate these exits, as they're forgotten forever here
    # TODO: implement
    {state, []}
  end

  @doc """
  All the active exits, in-flight exits, exiting output piggybacks etc., based on the current tracked state
  """
  @spec get_exiting_utxo_positions(t()) :: list(Utxo.Position.t())
  def get_exiting_utxo_positions(%__MODULE__{exits: exits} = _state) do
    exits
    |> Enum.filter(fn {_key, %{is_active: is_active}} -> is_active end)
    |> Enum.map(fn {utxo_pos, _value} -> utxo_pos end)
  end

  @doc """
  Based on the result of exit validity (utxo existence), return invalid exits or appropriate notifications

  NOTE: We're using `ExitStarted`-height with `sla_exit_margin` added on top, to determine old, unchallenged invalid
        exits. This is different than documented, according to what we ought to be using
        `exitable_at - sla_exit_margin_s` to determine such exits.

  NOTE: If there were any exits unchallenged for some time in chain history, this might detect breach of SLA,
        even if the exits were eventually challenged (e.g. during syncing)
  """
  @spec invalid_exits(list(boolean), t(), pos_integer) ::
          {list(Event.InvalidExit.t() | Event.UnchallengedExit.t()), :chain_ok | {:needs_stopping, :unchallenged_exit}}
  def invalid_exits(utxo_exists_result, %__MODULE__{exits: exits, sla_margin: sla_margin} = state, eth_height_now) do
    exiting_utxo_positions = get_exiting_utxo_positions(state)

    invalid_exit_positions =
      utxo_exists_result
      |> Enum.zip(exiting_utxo_positions)
      |> Enum.filter(fn {utxo_exists, _} -> !utxo_exists end)
      |> Enum.map(fn {_, position} -> position end)

    # get exits which are still invalid and after the SLA margin
    late_invalid_exits =
      exits
      |> Map.take(invalid_exit_positions)
      |> Enum.filter(fn {_, %{eth_height: eth_height}} -> eth_height + sla_margin <= eth_height_now end)

    has_no_late_invalid_exits = Enum.empty?(late_invalid_exits)

    non_late_events =
      invalid_exit_positions
      |> Enum.map(fn position -> make_event_data(Event.InvalidExit, position, exits[position]) end)

    events =
      late_invalid_exits
      |> Enum.map(fn {position, late_exit} -> make_event_data(Event.UnchallengedExit, position, late_exit) end)
      |> Enum.concat(non_late_events)

    chain_validity = if has_no_late_invalid_exits, do: :chain_ok, else: {:needs_stopping, :unchallenged_exit}

    {events, chain_validity}
  end

  defp make_event_data(type, position, exit_info) do
    struct(type, Map.put(exit_info, :utxo_pos, Utxo.Position.encode(position)))
  end
end
