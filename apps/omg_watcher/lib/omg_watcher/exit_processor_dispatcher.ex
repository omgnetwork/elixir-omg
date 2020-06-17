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

defmodule OMG.Watcher.ExitProcessorDispatcher do
  @moduledoc """
  Pretty sure it's doing some cool stuff.
  """

  require Logger

  @doc """
  Checks validity of all exit-related events and returns the list of actionable items.
  Works with `OMG.State` to discern validity.

  This function may also update some internal caches to make subsequent calls not redo the work,
  but under unchanged conditions, it should have unchanged behavior from POV of an outside caller.
  """
  def check_validity() do
    do_check_validity()
  end

  def check_validity(timeout) do
    do_check_validity(timeout)
  end

  defp do_check_validity(timeout \\ 5000) do
    {validity, events} =
      :check_validity
      |> forward(timeout)
      |> reduce_check_validity_result({:ok, []})

    {validity, events |> Enum.reverse() |> List.flatten()}
  end

  defp reduce_check_validity_result([], acc), do: acc

  defp reduce_check_validity_result(forwarded_results, acc) do
    [{chain_validity, events} | remainings] = forwarded_results
    {acc_chain_validity, acc_events} = acc

    case acc_chain_validity do
      :ok ->
        acc = {chain_validity, [events | acc_events]}
        reduce_check_validity_result(remainings, acc)

      {:error, :unchallenged_exit} ->
        acc = {{:error, :unchallenged_exit}, [events | acc_events]}
        reduce_check_validity_result(remainings, acc)
    end
  end

  @doc """
  Returns all information required to produce a transaction to the root chain contract to present a competitor for
  a non-canonical in-flight exit
  """
  def get_competitor_for_ife(txbytes) do
    forward_single_result({:get_competitor_for_ife, txbytes})
  end

  @doc """
  Returns all information required to produce a transaction to the root chain contract to present a proof of canonicity
  for a challenged in-flight exit
  """
  def prove_canonical_for_ife(txbytes) do
    forward_single_result({:prove_canonical_for_ife, txbytes})
  end

  @doc """
  Returns all information required to challenge an invalid input piggyback
  """
  def get_input_challenge_data(txbytes, input_index) do
    forward_single_result({:get_input_challenge_data, txbytes, input_index})
  end

  @doc """
  Returns all information required to challenge an invalid output piggyback
  """
  def get_output_challenge_data(txbytes, output_index) do
    forward_single_result({:get_output_challenge_data, txbytes, output_index})
  end

  @doc """
  Returns challenge for an invalid standard exit
  """
  def create_challenge(exiting_utxo_pos) do
    forward_single_result({:create_challenge, exiting_utxo_pos})
  end

  @doc """
  Returns a map of requested in flight exits, keyed by transaction hash
  """
  def get_active_in_flight_exits() do
    in_flight_exits =
      :get_active_in_flight_exits
      |> forward()
      |> Enum.reduce([], fn {:ok, exits}, acc -> [exits | acc] end)
      |> Enum.reverse()
      |> List.flatten()

    {:ok, in_flight_exits}
  end

  # TODO: move private funcs at the bottom of the file
  defp forward(func) do
    Enum.map(OMG.WireFormatTypes.exit_game_tx_types(), fn tx_type ->
      GenServer.call(tx_type, func)
    end)
  end

  defp forward(func, timeout) do
    Enum.map(OMG.WireFormatTypes.exit_game_tx_types(), fn tx_type ->
      GenServer.call(tx_type, func, timeout)
    end)
  end

  defp forward_single_result(func) do
    # From the results, it will try to find the first result with :ok status
    # Otherwise, one of the error status would be returned.
    find_first_ok_result_or_return_last(forward(func), {:error, :empty_forward_result})
  end

  defp find_first_ok_result_or_return_last([], last_result), do: last_result

  defp find_first_ok_result_or_return_last(forwarded_results, prev_result) do
    [current_result | tail] = forwarded_results
    {prev_status, _prev_data} = prev_result

    case prev_status do
      :ok -> prev_result
      _ -> find_first_ok_result_or_return_last(tail, current_result)
    end
  end

  defp dispatch(event_name, events) do
    db_updates =
      Enum.flat_map(group_events(events), fn {transaction_type, events} ->
        {:ok, db_updates} = GenServer.call(transaction_type, {event_name, events})
        db_updates
      end)

    {:ok, db_updates}
  end

  # This function filters the events into a map of the following format:
  # %{
  #   tx_payment_v1: [
  #     %{address: tx_payment_v1 contract, rest of event details...},
  #     %{address: tx_payment_v1 contract, rest of event details...},
  #   ],
  #   tx_payment_v2: []
  # }
  defp group_events(events) do
    # tx_type => address
    exit_games = OMG.Eth.Configuration.exit_games()

    Map.new(exit_games, fn {tx_type, address} ->
      grouped_events = Enum.filter(events, fn e -> e["address"] == address end)
      {tx_type, grouped_events}
    end)
  end

  @doc """
  Accepts events and processes them in the state - new exits are tracked.

  Returns `db_updates` to be sent to `OMG.DB` by the caller
  """
  # empty list clause to not block the server for no-ops
  def new_exits([]), do: {:ok, []}

  def new_exits(exits), do: dispatch(:new_exits, exits)

  @doc """
  Accepts events and processes them in the state - new in flight exits are tracked.

  Returns `db_updates` to be sent to `OMG.DB` by the caller
  """
  # empty list clause to not block the server for no-ops
  def new_in_flight_exits([]), do: {:ok, []}

  def new_in_flight_exits(in_flight_exit_started_events) do
    dispatch(:new_in_flight_exits, in_flight_exit_started_events)
  end

  @doc """
  Accepts events and processes them in the state - finalized exits are untracked _if valid_ otherwise raises alert

  Returns `db_updates` to be sent to `OMG.DB` by the caller
  """
  # empty list clause to not block the server for no-ops
  def finalize_exits([]), do: {:ok, []}

  def finalize_exits(finalizations) do
    dispatch(:finalize_exits, finalizations)
  end

  @doc """
  Accepts events and processes them in the state - new piggybacks are tracked, if invalid raises an alert

  Returns `db_updates` to be sent to `OMG.DB` by the caller
  """
  # empty list clause to not block the server for no-ops
  def piggyback_exits([]), do: {:ok, []}

  def piggyback_exits(piggybacks) do
    dispatch(:piggyback_exits, piggybacks)
  end

  @doc """
  Accepts events and processes them in the state - challenged exits are untracked

  Returns `db_updates` to be sent to `OMG.DB` by the caller
  """
  # empty list clause to not block the server for no-ops
  def challenge_exits([]), do: {:ok, []}

  def challenge_exits(challenges) do
    dispatch(:challenge_exits, challenges)
  end

  @doc """
  Accepts events and processes them in the state.

  Marks the challenged IFE as non-canonical and persists information about the competitor and its age.

  Competitors are stored for future use (i.e. to challenge an in flight exit).

  Returns `db_updates` to be sent to `OMG.DB` by the caller
  """
  # empty list clause to not block the server for no-ops
  def new_ife_challenges([]), do: {:ok, []}

  def new_ife_challenges(challenges) do
    dispatch(:new_ife_challenges, challenges)
  end

  @doc """
  Accepts events and processes them in state.

  Marks the IFE as canonical and perists information about the inclusion age as responded with in the contract.

  Returns `db_updates` to be sent to `OMG.DB` by the caller
  """
  # empty list clause to not block the server for no-ops
  def respond_to_in_flight_exits_challenges([]), do: {:ok, []}

  def respond_to_in_flight_exits_challenges(responds) do
    dispatch(:respond_to_in_flight_exits_challenges, responds)
  end

  @doc """
  Accepts events and processes them in state.

  Returns `db_updates` to be sent to `OMG.DB` by the caller
  """
  # empty list clause to not block the server for no-ops
  def challenge_piggybacks([]), do: {:ok, []}

  def challenge_piggybacks(challenges) do
    dispatch(:challenge_piggybacks, challenges)
  end

  @doc """
  Accepts events and processes them in state - finalized outputs are applied to the state.

  Returns `db_updates` to be sent to `OMG.DB` by the caller
  """
  # empty list clause to not block the server for no-ops
  def finalize_in_flight_exits([]), do: {:ok, []}

  def finalize_in_flight_exits(finalizations) do
    dispatch(:finalize_in_flight_exits, finalizations)
  end
end
