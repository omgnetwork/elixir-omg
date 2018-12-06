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

defmodule OMG.Watcher.ExitProcessor.Core do
  @moduledoc """
  The functional, zero-side-effect part of the exit processor. Logic should go here:
    - orchestrating the persistence of the state
    - finding invalid exits, disseminating them as events according to rules
    - MoreVP protocol managing should go here
  """

  alias OMG.API.Crypto
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Watcher.Event
  alias OMG.Watcher.ExitProcessor.ExitInfo
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo

  @default_sla_margin 10
  @zero_address Crypto.zero_address()

  defstruct [:sla_margin, exits: %{}, in_flight_exits: %{}]

  @type t :: %__MODULE__{
          sla_margin: non_neg_integer(),
          exits: %{Utxo.Position.t() => ExitInfo.t()},
          in_flight_exits: %{binary() => InFlightExitInfo.t()}
        }

  @doc """
  Reads database-specific list of exits and turns them into current state
  """
  @spec init(db_exits :: [{{pos_integer, non_neg_integer, non_neg_integer}, map}], non_neg_integer) :: {:ok, t()}
  def init(db_exits, sla_margin \\ @default_sla_margin) do
    {:ok,
     %__MODULE__{
       exits:
         db_exits
         |> Enum.map(fn {{blknum, txindex, oindex}, v} ->
           {Utxo.position(blknum, txindex, oindex), struct(ExitInfo, v)}
         end)
         |> Map.new(),
       # TODO: init
       in_flight_exits: Map.new(),
       sla_margin: sla_margin
     }}
  end

  @doc """
  Add new exits from Ethereum events into tracked state.

  The list of `exit_contract_statuses` is used to track current (as in wall-clock "now", not syncing "now") status.
  This is to prevent spurrious invalid exit events being fired during syncing for exits that were challenged/finalized
  Still we do want to track these exits when syncing, to have them spend from `OMG.API.State` on their finalization
  """
  @spec new_exits(t(), list(map()), list(map)) :: {t(), list()} | {:error, :unexpected_events}
  def new_exits(state, new_exits, exit_contract_statuses)

  def new_exits(_, new_exits, exit_contract_statuses) when length(new_exits) != length(exit_contract_statuses) do
    {:error, :unexpected_events}
  end

  def new_exits(%__MODULE__{exits: exits} = state, new_exits, exit_contract_statuses) do
    new_exits_kv_pairs =
      new_exits
      |> Enum.zip(exit_contract_statuses)
      |> Enum.map(fn {%{utxo_pos: utxo_pos} = exit_info, contract_status} ->
        is_active = parse_contract_status(contract_status)
        map_exit_info = exit_info |> Map.delete(:utxo_pos) |> Map.put(:is_active, is_active)
        {Utxo.Position.decode(utxo_pos), struct(ExitInfo, map_exit_info)}
      end)

    db_updates =
      new_exits_kv_pairs
      |> Enum.map(&ExitInfo.make_db_update/1)

    new_exits_map = Map.new(new_exits_kv_pairs)

    {%{state | exits: Map.merge(exits, new_exits_map)}, db_updates}
  end

  defp parse_contract_status({@zero_address, _contract_token, _contract_amount}), do: false
  defp parse_contract_status({_contract_owner, _contract_token, _contract_amount}), do: true

  @doc """

  """
  @spec new_in_flight_exits(t(), [map()], [map()]) :: t() | {:error, :unexpected_events}
  def new_in_flight_exits(state, exits, in_flight_exits_contract_data)

  def new_in_flight_exits(state, exits, in_flight_exits_contract_data)
      when length(exits) != length(in_flight_exits_contract_data),
      do: {:error, :unexpected_events}

  def new_in_flight_exits(state, exits, in_flight_exits_contract_data) do
    # TODO
  end

  @doc """
  Finalize exits based on Ethereum events, removing from tracked state if valid.

  Invalid finalizing exits should continue being tracked as `is_active`, to continue emitting events.
  This includes non-`is_active` exits that finalize invalid, which are turned to be `is_active` now.
  """
  @spec finalize_exits(t(), validities :: {list(Utxo.Position.t()), list(Utxo.Position.t())}) :: {t(), list()}
  def finalize_exits(%__MODULE__{exits: exits} = state, {valid_finalizations, invalid}) do
    # handling valid finalizations
    state = %{state | exits: Map.drop(exits, valid_finalizations)}
    db_updates = delete_positions(valid_finalizations)

    {state, activating_db_updates} = activate_on_invalid_finalization(state, invalid)

    {state, db_updates ++ activating_db_updates}
  end

  defp activate_on_invalid_finalization(%__MODULE__{exits: exits} = state, invalid_finalizations) do
    exits_to_activate =
      exits
      |> Map.take(invalid_finalizations)
      |> Enum.map(fn {k, v} -> {k, Map.update!(v, :is_active, fn _ -> true end)} end)
      |> Map.new()

    activating_db_updates =
      exits_to_activate
      |> Enum.map(&ExitInfo.make_db_update/1)

    state = %{state | exits: Map.merge(exits, exits_to_activate)}
    {state, activating_db_updates}
  end

  @spec challenge_exits(t(), list(map)) :: {t(), list}
  def challenge_exits(%__MODULE__{exits: exits} = state, challenges) do
    challenged_positions = get_positions_from_events(challenges)
    state = %{state | exits: Map.drop(exits, challenged_positions)}
    db_updates = delete_positions(challenged_positions)
    {state, db_updates}
  end

  defp get_positions_from_events(exits) do
    exits
    |> Enum.map(fn %{utxo_pos: utxo_pos} = _finalization_info -> Utxo.Position.decode(utxo_pos) end)
  end

  defp delete_positions(utxo_positions) do
    utxo_positions
    |> Enum.map(fn Utxo.position(blknum, txindex, oindex) -> {:delete, :exit_info, {blknum, txindex, oindex}} end)
  end

  @doc """
  All the active exits, in-flight exits, exiting output piggybacks etc., based on the current tracked state
  """
  @spec get_exiting_utxo_positions(t()) :: list(Utxo.Position.t())
  def get_exiting_utxo_positions(%__MODULE__{exits: exits} = _state) do
    exits
    |> Enum.filter(fn {_key, %ExitInfo{is_active: is_active}} -> is_active end)
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
  @spec invalid_exits(list(boolean), t(), pos_integer, non_neg_integer) ::
          {:ok | {:error, :unchallenged_exit}, list(Event.InvalidExit.t() | Event.UnchallengedExit.t())}
  def invalid_exits(
        utxo_exists_result,
        %__MODULE__{exits: exits, sla_margin: sla_margin} = state,
        eth_height_now,
        blknum_now
      ) do
    exiting_utxo_positions = get_exiting_utxo_positions(state)

    invalid_exit_positions =
      utxo_exists_result
      |> Stream.zip(exiting_utxo_positions)
      |> Stream.filter(fn {utxo_exists, _} -> !utxo_exists end)
      |> Stream.filter(fn {_, Utxo.position(blknum, _, _)} -> blknum < blknum_now end)
      |> Stream.map(fn {_, position} -> position end)

    # get exits which are still invalid and after the SLA margin
    late_invalid_exits =
      exits
      |> Map.take(invalid_exit_positions)
      |> Enum.filter(fn {_, %ExitInfo{eth_height: eth_height}} -> eth_height + sla_margin <= eth_height_now end)

    has_no_late_invalid_exits = Enum.empty?(late_invalid_exits)

    non_late_events =
      invalid_exit_positions
      |> Enum.map(fn position -> ExitInfo.make_event_data(Event.InvalidExit, position, exits[position]) end)

    events =
      late_invalid_exits
      |> Enum.map(fn {position, late_exit} -> ExitInfo.make_event_data(Event.UnchallengedExit, position, late_exit) end)
      |> Enum.concat(non_late_events)

    chain_validity = if has_no_late_invalid_exits, do: :ok, else: {:error, :unchallenged_exit}

    {chain_validity, events}
  end
end
