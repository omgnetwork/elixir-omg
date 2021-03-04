# Copyright 2019-2020 OMG Network Pte Ltd
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
  state of the ledger (`OMG.Watcher.State`), issues notifications as it finds suitable.

  Should manage all kinds of exits allowed in the protocol and handle the interactions between them.

  This is the functional, zero-side-effect part of the exit processor. Logic should go here:
    - orchestrating the persistence of the state
    - finding invalid exits, disseminating them as events according to rules
    - enabling to challenge invalid exits
    - figuring out critical failure of invalid exit challenging (aka `:unchallenged_exit` event)
    - MoreVP protocol managing in general

  For the imperative shell, see `OMG.Watcher.ExitProcessor`
  """

  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.ExitInfo
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo
  alias OMG.Watcher.State.Transaction
  alias OMG.Watcher.Utxo

  require Logger

  require Utxo

  @doc """
  Finalize exits based on Ethereum events, removing from tracked state if valid.

  Invalid finalizing exits should continue being tracked as `is_active`, to continue emitting events.
  This includes non-`is_active` exits that finalize invalid, which are turned to be `is_active` now.
  """
  @spec finalize_exits(Core.t(), validities :: {list(Utxo.Position.t()), list(Utxo.Position.t())}) ::
          {Core.t(), list(), list()}
  def finalize_exits(%Core{exits: exits} = state, {valid_finalizations, invalid}) do
    # handling valid finalizations

    new_exits_kv_pairs =
      exits
      |> Map.take(valid_finalizations)
      |> Enum.into(%{}, fn {utxo_pos, exit_info} -> {utxo_pos, %ExitInfo{exit_info | is_active: false}} end)

    new_state1 = %{state | exits: Map.merge(exits, new_exits_kv_pairs)}
    db_updates = new_exits_kv_pairs |> Enum.map(&ExitInfo.make_db_update/1)

    # invalid ones - activating, in case they were inactive, to keep being invalid forever
    {new_state2, activating_db_updates} = activate_on_invalid_finalization(new_state1, invalid)

    {new_state2, db_updates ++ activating_db_updates}
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
  Returns a tuple of `{:ok, %{ife_exit_id => {finalized_input_exits | finalized_output_exits}}, list(events_exits)}`.
  Finalized input exits and finalized output exits structures both fit into `OMG.Watcher.State.exit_utxos/1`.
  Events exits list contains Ethereum's finalization events paired with utxos they exits. This data is needed to
  broadcast information to the consumers about utxos that needs to marked as spend as the result of finalization.

  When there are invalid finalizations, returns one of the following:
    - {:inactive_piggybacks_finalizing, list of piggybacks that exit processor state is not aware of}
    - {:unknown_in_flight_exit, set of in-flight exit ids that exit processor is not aware of}
  """
  @spec prepare_utxo_exits_for_in_flight_exit_finalizations(Core.t(), [map()]) ::
          {:ok, map(), list()}
          | {:inactive_piggybacks_finalizing, list()}
          | {:unknown_in_flight_exit, MapSet.t(non_neg_integer())}
  def prepare_utxo_exits_for_in_flight_exit_finalizations(%Core{in_flight_exits: ifes}, finalizations) do
    finalizations = finalizations |> Enum.map(&ife_id_to_binary/1)

    with {:ok, ifes_by_id} <- get_all_finalized_ifes_by_ife_contract_id(finalizations, ifes),
         {:ok, []} <- known_piggybacks?(finalizations, ifes_by_id) do
      {exiting_positions_by_ife_id, events_with_positions} =
        finalizations
        |> Enum.reverse()
        |> Enum.reduce({%{}, []}, &combine_utxo_exits_with_finalization(&1, &2, ifes_by_id))

      {
        :ok,
        exiting_positions_by_ife_id,
        Enum.reject(events_with_positions, &Kernel.match?({_, []}, &1))
      }
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
      |> Enum.map(fn {_tx_hash, %InFlightExitInfo{contract_id: id} = ife} -> {id, ife} end)
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
    finalizations
    |> Enum.filter(&finalization_not_piggybacked?(&1, ifes_by_id))
    |> case do
      [] -> {:ok, []}
      not_piggybacked -> {:inactive_piggybacks_finalizing, not_piggybacked}
    end
  end

  defp finalization_not_piggybacked?(
         %{in_flight_exit_id: ife_id, output_index: output_index, omg_data: %{piggyback_type: piggyback_type}},
         ifes_by_id
       ),
       do: not InFlightExitInfo.is_active?(ifes_by_id[ife_id], {piggyback_type, output_index})

  defp combine_utxo_exits_with_finalization(
         %{in_flight_exit_id: ife_id, output_index: output_index, omg_data: %{piggyback_type: piggyback_type}} = event,
         {exiting_positions, events_with_positions},
         ifes_by_id
       ) do
    ife = ifes_by_id[ife_id]
    # a runtime sanity check - if this were false it would mean all piggybacks finalized so contract wouldn't allow that
    true = InFlightExitInfo.is_active?(ife, {piggyback_type, output_index})

    # figure out if there's any UTXOs really exiting from the `OMG.Watcher.State`
    # from this IFE's piggybacked input/output
    exiting_positions_for_piggyback = get_exiting_positions(ife, output_index, piggyback_type)

    {
      Map.update(exiting_positions, ife_id, exiting_positions_for_piggyback, &(exiting_positions_for_piggyback ++ &1)),
      [{event, exiting_positions_for_piggyback} | events_with_positions]
    }
  end

  defp get_exiting_positions(ife, output_index, :input) do
    %InFlightExitInfo{tx: %Transaction.Signed{raw_tx: tx}} = ife
    input_position = tx |> Transaction.get_inputs() |> Enum.at(output_index)
    [input_position]
  end

  defp get_exiting_positions(ife, output_index, :output) do
    case ife.tx_seen_in_blocks_at do
      nil -> []
      {Utxo.position(blknum, txindex, _), _proof} -> [Utxo.position(blknum, txindex, output_index)]
    end
  end

  @doc """
  Finalizes in-flight exits.

  Returns a tuple of {:ok, updated state, database updates}.
  When there are invalid finalizations, returns one of the following:
    - {:inactive_piggybacks_finalizing, list of piggybacks that exit processor state is not aware of}
    - {:unknown_in_flight_exit, set of in-flight exit ids that exit processor is not aware of}
  """
  @spec finalize_in_flight_exits(Core.t(), [map()], map()) ::
          {:ok, Core.t(), list()}
          | {:inactive_piggybacks_finalizing, list()}
          | {:unknown_in_flight_exit, MapSet.t(non_neg_integer())}
  def finalize_in_flight_exits(%Core{in_flight_exits: ifes} = state, finalizations, invalidities_by_ife_id) do
    # convert ife_id from int (given by contract) to a binary
    finalizations = Enum.map(finalizations, &ife_id_to_binary/1)

    with {:ok, ifes_by_id} <- get_all_finalized_ifes_by_ife_contract_id(finalizations, ifes),
         {:ok, []} <- known_piggybacks?(finalizations, ifes_by_id) do
      {ifes_by_id, updated_ifes} =
        finalizations
        |> Enum.reduce({ifes_by_id, MapSet.new()}, &finalize_single_exit/2)
        |> activate_on_invalid_utxo_exits(invalidities_by_ife_id)

      db_updates =
        ifes_by_id
        |> Map.take(Enum.to_list(updated_ifes))
        |> Map.values()
        # re-key those IFEs by tx_hash as how they are originally stored
        |> Enum.map(&{Transaction.raw_txhash(&1.tx), &1})
        |> Enum.map(&InFlightExitInfo.make_db_update/1)

      ifes =
        ifes_by_id
        # re-key those IFEs by tx_hash as how they are originally stored
        |> Map.values()
        |> Enum.into(%{}, &{Transaction.raw_txhash(&1.tx), &1})

      {:ok, %{state | in_flight_exits: ifes}, db_updates}
    end
  end

  defp finalize_single_exit(
         %{in_flight_exit_id: ife_id, output_index: output_index, omg_data: %{piggyback_type: piggyback_type}},
         {ifes_by_id, updated_ifes}
       ) do
    combined_index = {piggyback_type, output_index}
    ife = ifes_by_id[ife_id]

    if InFlightExitInfo.is_active?(ife, combined_index) do
      {:ok, finalized_ife} = InFlightExitInfo.finalize(ife, combined_index)
      ifes_by_id = Map.put(ifes_by_id, ife_id, finalized_ife)
      updated_ifes = MapSet.put(updated_ifes, ife_id)

      {ifes_by_id, updated_ifes}
    else
      {ifes_by_id, updated_ifes}
    end
  end

  defp activate_on_invalid_utxo_exits({ifes_by_id, updated_ifes}, invalidities_by_ife_id) do
    ids_to_activate =
      invalidities_by_ife_id
      |> Enum.filter(fn {_ife_id, invalidities} -> not Enum.empty?(invalidities) end)
      |> Enum.map(fn {ife_id, _invalidities} -> ife_id end)
      |> MapSet.new()

    # iterates over the ifes that are spotted with invalid finalizing (their `ife_ids`) and activates the ifes
    new_ifes_by_id =
      Enum.reduce(ids_to_activate, ifes_by_id, fn id, ifes -> Map.update!(ifes, id, &InFlightExitInfo.activate/1) end)

    {new_ifes_by_id, MapSet.union(ids_to_activate, updated_ifes)}
  end
end
