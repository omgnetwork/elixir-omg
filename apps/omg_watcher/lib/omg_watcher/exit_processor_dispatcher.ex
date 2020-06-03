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

  @doc """
  Checks validity of all exit-related events and returns the list of actionable items.
  Works with `OMG.State` to discern validity.

  This function may also update some internal caches to make subsequent calls not redo the work,
  but under unchanged conditions, it should have unchanged behavior from POV of an outside caller.
  """
  def check_validity(), do: forward(:check_validity)
  def check_validity(timeout), do: forward(:check_validity, timeout)

  @doc """
  Returns a map of requested in flight exits, keyed by transaction hash
  """
  def get_active_in_flight_exits() do
    in_flight_exits =
      :get_active_in_flight_exits
      |> forward()
      |> Enum.reduce([], fn {:ok, in_flight_exits}, acc ->
        acc ++ in_flight_exits
      end)

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

  defp dispatch(event_name, events) do
    Enum.each(filter_events(events), fn {transaction_type, events} ->
      # We reverse the events since we're getting them back
      # in the wrong order from the filter_events() function
      GenServer.call(transaction_type, {event_name, Enum.reverse(events)})
    end)
  end

  # This function filters the events into a map of the following format:
  # %{
  #   tx_payment_v1: [
  #     %{address: tx_payment_v1 contract, rest of event details...},
  #     %{address: tx_payment_v1 contract, rest of event details...},
  #   ],
  #   tx_payment_v2: []
  # }
  defp filter_events(events) do
    # First we get the list of exit game contracts from the configuration
    # tx_type => address
    exit_games = OMG.Eth.Configuration.exit_games()

    # We reverse that list to easily get the type from an address
    # We need this since the tx_type is used as the identifier
    # for our exit processor genservers
    reversed_exit_games = Map.new(exit_games, fn {k, v} -> {v, k} end)

    # Filter events based on which exit games they're coming from
    events
    |> Enum.reduce(%{}, fn event, exit_games_with_events ->
      case reversed_exit_games[event["address"]] do
        nil ->
          exit_games_with_events

        tx_type ->
          current_events = exit_games_with_events[event["address"]] || []
          Map.put(exit_games_with_events, tx_type, [event | current_events])
      end
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
