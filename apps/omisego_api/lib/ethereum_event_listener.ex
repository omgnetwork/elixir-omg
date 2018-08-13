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

defmodule OmiseGO.API.EthereumEventListener do
  @moduledoc """
  Periodically fetches events made on dynamically changing block range
  on parent chain and feeds them to state.
  For code simplicity it listens for events in blocks with a configured finality margin.
  """

  alias OmiseGO.API.EthereumEventListener.Core
  alias OmiseGO.API.RootchainCoordinator
  alias OmiseGO.Eth
  use OmiseGO.API.LoggerExt

  ### Client

  def start_link(config, get_events_callback, process_events_callback) do
    GenServer.start_link(__MODULE__, {config, get_events_callback, process_events_callback})
  end

  ### Server

  use GenServer

  def init(
        {%{block_finality_margin: finality_margin, service_name: service_name}, get_ethereum_events_callback,
         process_events_callback}
      ) do
    # TODO: initialize state with the last ethereum block we have seen events from
    {:ok, parent_start_height} = Eth.get_root_deployment_height()

    schedule_get_events()

    _ = Logger.info(fn -> "Starting EthereumEventListener" end)

    :ok = RootchainCoordinator.set_service_height(parent_start_height, service_name)

    {:ok,
     %Core{
       next_event_height_lower_bound: parent_start_height,
       synced_height: parent_start_height,
       service_name: service_name,
       block_finality_margin: finality_margin,
       get_ethereum_events_callback: get_ethereum_events_callback,
       process_events_callback: process_events_callback
     }}
  end

  def handle_info(:get_events, state) do
    case RootchainCoordinator.get_height() do
      :no_sync ->
        {:noreply, state}

      {:sync, next_sync_height} ->
        new_state = sync_height(state, next_sync_height)
        {:noreply, new_state}
    end
  end

  defp sync_height(state, next_sync_height) do
    case Core.next_events_block_range(state, next_sync_height) do
      {:get_events, {event_height_lower_bound, event_height_upper_bound}, state} ->
        {:ok, events} = state.get_ethereum_events_callback.(event_height_lower_bound, event_height_upper_bound)
        IO.puts("#{inspect(state.service_name)} - #{inspect(state.synced_height)} - #{inspect(events)}")
        :ok = state.process_events_callback.(events)
        :ok = RootchainCoordinator.set_service_height(next_sync_height, state.service_name)

        _ =
          Logger.debug(fn ->
            "get_events called successfully with '#{inspect(Enum.count(events))}' events processed."
          end)

        state

      {:dont_get_events, state} ->
        _ = Logger.debug(fn -> "No blocks with event" end)
        state
    end
  end

  defp schedule_get_events(interval \\ 200) do
    :timer.send_interval(interval, self(), :get_events)
  end
end
