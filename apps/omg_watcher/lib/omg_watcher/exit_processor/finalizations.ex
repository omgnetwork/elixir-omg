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

defmodule OMG.Watcher.ExitProcessor.Finalizations do
  @moduledoc """
  Encapsulates managing and executing the behaviors related to treating exits by the child chain and watchers
  Keeps a state of exits that are in progress, updates it with news from the root chain, compares to the
  state of the ledger (`OMG.State`), issues notifications as it finds suitable.

  Should manage all kinds of exits allowed in the protocol and handle the interactions between them.

  This is the functional, zero-side-effect part of the exit processor. Logic should go here:
    - orchestrating the persistence of the state
    - finding invalid exits, disseminating them as events according to rules
    - enabling to challenge invalid exits
    - figuring out critical failure of invalid exit challenging (aka `:unchallenged_exit` event)
    - MoreVP protocol managing in general

  For the imperative shell, see `OMG.Watcher.ExitProcessor`
  """

  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.ExitInfo
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo

  use OMG.Utils.LoggerExt

  @doc """
  Finalize exits based on Ethereum events, removing from tracked state if valid.

  Invalid finalizing exits should continue being tracked as `is_active`, to continue emitting events.
  This includes non-`is_active` exits that finalize invalid, which are turned to be `is_active` now.
  """
  @spec finalize_exits(Core.t(), validities :: {list(Utxo.Position.t()), list(Utxo.Position.t())}) ::
          {Core.t(), list(), list()}
  def finalize_exits(%Core{exits: exits} = state, {valid_finalizations, invalid}) do
    # handling valid finalizations
    exit_event_triggers =
      valid_finalizations
      |> Enum.map(fn utxo_pos ->
        %ExitInfo{owner: owner, currency: currency, amount: amount} = exits[utxo_pos]

        %{exit_finalized: %{owner: owner, currency: currency, amount: amount, utxo_pos: utxo_pos}}
      end)

    new_exits_kv_pairs =
      exits
      |> Map.take(valid_finalizations)
      |> Enum.into(%{}, fn {utxo_pos, exit_info} -> {utxo_pos, %ExitInfo{exit_info | is_active: false}} end)

    new_state1 = %{state | exits: Map.merge(exits, new_exits_kv_pairs)}
    db_updates = new_exits_kv_pairs |> Enum.map(&ExitInfo.make_db_update/1)

    # invalid ones - activating, in case they were inactive, to keep being invalid forever
    {new_state2, activating_db_updates} = activate_on_invalid_finalization(new_state1, invalid)

    {new_state2, exit_event_triggers, db_updates ++ activating_db_updates}
  end

  defp activate_on_invalid_finalization(%Core{exits: exits} = state, invalid_finalizations) do
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

  @doc """
  Returns a tuple of {:ok, map in-flight exit id => {finalized input exits, finalized output exits}}.
  finalized input exits and finalized output exits structures both fit into `OMG.State.exit_utxos/1`.

  When there are invalid finalizations, returns one of the following:
    - {:unknown_piggybacks, list of piggybacks that exit processor state is not aware of}
    - {:unknown_in_flight_exit, set of in-flight exit ids that exit processor is not aware of}
  """
  @spec prepare_utxo_exits_for_in_flight_exit_finalizations(Core.t(), [map()]) ::
          {:ok, map()}
          | {:unknown_piggybacks, list()}
          | {:unknown_in_flight_exit, MapSet.t(non_neg_integer())}
  def prepare_utxo_exits_for_in_flight_exit_finalizations(%Core{in_flight_exits: ifes}, finalizations) do
    finalizations = finalizations |> Enum.map(&ife_id_to_binary/1)

    with {:ok, ifes_by_id} <- get_all_finalized_ifes_by_ife_contract_id(finalizations, ifes),
         {:ok, []} <- known_piggybacks?(finalizations, ifes_by_id) do
      {exits_by_ife_id, _} =
        finalizations
        |> Enum.reduce({%{}, ifes_by_id}, &prepare_utxo_exits_for_finalization/2)

      {:ok, exits_by_ife_id}
    end
  end

  # converts from int, which is how the contract serves it
  defp ife_id_to_binary(finalization),
    do: Map.update!(finalization, :in_flight_exit_id, fn id -> <<id::192>> end)

  defp get_all_finalized_ifes_by_ife_contract_id(finalizations, ifes) do
    finalizations_ids =
      finalizations
      |> Enum.map(fn %{in_flight_exit_id: id} -> id end)
      |> MapSet.new()

    by_contract_id =
      ifes
      |> Enum.map(fn {tx_hash, %InFlightExitInfo{contract_id: id} = ife} -> {id, {tx_hash, ife}} end)
      |> Map.new()

    known_ifes =
      by_contract_id
      |> Map.keys()
      |> MapSet.new()

    unknown_ifes = MapSet.difference(finalizations_ids, known_ifes)

    if Enum.empty?(unknown_ifes) do
      {:ok, by_contract_id}
    else
      {:unknown_in_flight_exit, unknown_ifes}
    end
  end

  defp known_piggybacks?(finalizations, ifes_by_id) do
    not_piggybacked =
      finalizations
      |> Enum.filter(fn %{in_flight_exit_id: ife_id, output_index: output} ->
        {_, ife} = Map.get(ifes_by_id, ife_id)
        not InFlightExitInfo.is_piggybacked?(ife, output)
      end)

    if Enum.empty?(not_piggybacked) do
      {:ok, []}
    else
      {:unknown_piggybacks, not_piggybacked}
    end
  end

  defp prepare_utxo_exits_for_finalization(
         %{in_flight_exit_id: ife_id, output_index: output},
         {exits, ifes_by_id}
       ) do
    {tx_hash, ife} = Map.get(ifes_by_id, ife_id)
    # a runtime sanity check - if this were false it would mean all piggybacks finalized so contract wouldn't allow that
    true = InFlightExitInfo.is_active?(ife, output)

    {input_exits, output_exits} =
      if output >= 4 do
        {[], [%{tx_hash: tx_hash, output_index: output}]}
      else
        %InFlightExitInfo{tx: %Transaction.Signed{raw_tx: tx}} = ife
        input_exit = tx |> Transaction.get_inputs() |> Enum.at(output)
        {[input_exit], []}
      end

    {input_exits_acc, output_exits_acc} = Map.get(exits, ife_id, {[], []})
    exits = Map.put(exits, ife_id, {input_exits ++ input_exits_acc, output_exits ++ output_exits_acc})
    {exits, ifes_by_id}
  end

  @doc """
  Finalizes in-flight exits.

  Returns a tuple of {:ok, updated state, database updates}.
  When there are invalid finalizations, returns one of the following:
    - {:unknown_piggybacks, list of piggybacks that exit processor state is not aware of}
    - {:unknown_in_flight_exit, set of in-flight exit ids that exit processor is not aware of}
  """
  @spec finalize_in_flight_exits(Core.t(), [map()], map()) ::
          {:ok, Core.t(), list()}
          | {:unknown_piggybacks, list()}
          | {:unknown_in_flight_exit, MapSet.t(non_neg_integer())}
  def finalize_in_flight_exits(%Core{in_flight_exits: ifes} = state, finalizations, invalidities_by_ife_id) do
    # convert ife_id from int (given by contract) to a binary
    finalizations =
      finalizations
      |> Enum.map(fn %{in_flight_exit_id: id} = map -> Map.replace!(map, :in_flight_exit_id, <<id::192>>) end)

    with {:ok, ifes_by_id} <- get_all_finalized_ifes_by_ife_contract_id(finalizations, ifes),
         {:ok, []} <- known_piggybacks?(finalizations, ifes_by_id) do
      {ifes_by_id, updated_ifes} =
        finalizations
        |> Enum.reduce({ifes_by_id, MapSet.new()}, &finalize_single_exit/2)
        |> activate_on_invalid_utxo_exits(invalidities_by_ife_id)

      db_updates =
        Map.new(ifes_by_id)
        |> Map.take(updated_ifes)
        |> Enum.map(fn {_, value} -> value end)
        |> Enum.map(&InFlightExitInfo.make_db_update/1)

      ifes =
        ifes_by_id
        |> Enum.map(fn {_, value} -> value end)
        |> Map.new()

      {:ok, %{state | in_flight_exits: ifes}, db_updates}
    end
  end

  defp finalize_single_exit(
         %{in_flight_exit_id: ife_id, output_index: output},
         {ifes_by_id, updated_ifes}
       ) do
    {tx_hash, ife} = Map.get(ifes_by_id, ife_id)

    if InFlightExitInfo.is_active?(ife, output) do
      {:ok, finalized_ife} = InFlightExitInfo.finalize(ife, output)
      ifes_by_id = Map.put(ifes_by_id, ife_id, {tx_hash, finalized_ife})
      updated_ifes = MapSet.put(updated_ifes, ife_id)

      {ifes_by_id, updated_ifes}
    else
      {ifes_by_id, updated_ifes}
    end
  end

  defp activate_on_invalid_utxo_exits({ifes_by_id, updated_ifes}, invalidities_by_ife_id) do
    ifes_to_activate =
      invalidities_by_ife_id
      |> Enum.filter(fn {_ife_id, invalidities} -> not Enum.empty?(invalidities) end)
      |> Enum.map(fn {ife_id, _invalidities} -> ife_id end)
      |> MapSet.new()

    ifes_by_id = Enum.map(ifes_by_id, &activate_in_flight_exit(&1, ifes_to_activate))

    updated_ifes = MapSet.to_list(ifes_to_activate) ++ MapSet.to_list(updated_ifes)
    updated_ifes = MapSet.new(updated_ifes)

    {ifes_by_id, updated_ifes}
  end

  defp activate_in_flight_exit({ife_id, {tx_hash, ife}}, ifes_to_activate) do
    if MapSet.member?(ifes_to_activate, ife_id) do
      activated_ife = InFlightExitInfo.activate(ife)
      {ife_id, {tx_hash, activated_ife}}
    else
      {ife_id, {tx_hash, ife}}
    end
  end
end
