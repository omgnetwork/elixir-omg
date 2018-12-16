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

defmodule OMG.API.EthereumEventListener do
  @moduledoc """
  Periodically fetches events made on dynamically changing block range
  on parent chain and feeds them to a callback.
  For code simplicity it listens for events from blocks with a configured finality margin.

  NOTE: this could and should at some point be implemented as a `@behavior` instead, to avoid using callbacks
  """
  alias OMG.API.EthereumEventListener.Core
  alias OMG.API.RootChainCoordinator

  use OMG.API.LoggerExt

  @type config() :: %{
          block_finality_margin: non_neg_integer,
          synced_height_update_key: atom,
          service_name: atom,
          # maps a pair denoting eth height range to a list of ethereum events
          get_events_callback: (non_neg_integer, non_neg_integer -> {:ok, [map]}),
          # maps a list of ethereum events to a list of `db_updates` to send to `OMG.DB`
          process_events_callback: ([any] -> {:ok, [tuple]}),
          # returns an eth height where ethereum event processing last synced to
          get_last_synced_height_callback: (() -> {:ok, non_neg_integer})
        }

  ### Client

  @spec start_link(config()) :: GenServer.on_start()
  def start_link(config) do
    %{service_name: name} = config
    GenServer.start_link(__MODULE__, config, name: name)
  end

  ### Server

  use GenServer

  def init(%{
        block_finality_margin: finality_margin,
        synced_height_update_key: update_key,
        service_name: service_name,
        get_events_callback: get_events_callback,
        process_events_callback: process_events_callback,
        get_last_synced_height_callback: last_event_block_height_callback
      }) do
    {:ok, contract_deployment_height} = OMG.Eth.RootChain.get_root_deployment_height()
    {:ok, last_event_block_height} = last_event_block_height_callback.()

    # we don't need to ever look at earlier than contract deployment
    last_event_block_height = max(last_event_block_height, contract_deployment_height)

    {:ok, _} = schedule_get_events(Application.fetch_env!(:omg_api, :ethereum_status_check_interval_ms))
    :ok = RootChainCoordinator.check_in(last_event_block_height, service_name)

    _ = Logger.info(fn -> "Starting EthereumEventListener for #{service_name}" end)

    {:ok,
     {Core.init(update_key, service_name, last_event_block_height, finality_margin),
      %{
        get_ethereum_events_callback: get_events_callback,
        process_events_callback: process_events_callback
      }}}
  end

  def handle_info(:sync, {core, _callbacks} = state) do
    case RootChainCoordinator.get_height() do
      :nosync ->
        :ok = RootChainCoordinator.check_in(core.synced_height, core.service_name)
        {:noreply, state}

      {:sync, next_sync_height} ->
        new_state = sync_height(state, next_sync_height)
        {:noreply, new_state}
    end
  end

  #  def handle_info(:sync, {%{sync_mode: :sync_with_root_chain}, _callbacks} = state) do
  #    {:ok, root_chain_height} = Eth.get_ethereum_height()
  #    new_state = sync_height(state, root_chain_height)
  #    {:noreply, new_state}
  #  end

  defp sync_height({core, callbacks}, next_sync_height) do
    case Core.get_events_height_range_for_next_sync(core, next_sync_height) do
      {:get_events, {event_height_lower_bound, event_height_upper_bound}, core, db_updates} ->
        {:ok, events} = callbacks.get_ethereum_events_callback.(event_height_lower_bound, event_height_upper_bound)
        {:ok, db_updates_from_callback} = callbacks.process_events_callback.(events)
        :ok = OMG.DB.multi_update(db_updates ++ db_updates_from_callback)
        :ok = RootChainCoordinator.check_in(next_sync_height, core.service_name)

        _ =
          Logger.debug(fn ->
            "#{inspect(core.service_name)} processed '#{inspect(Enum.count(events))}' events."
          end)

        {core, callbacks}

      {:dont_get_events, core} ->
        _ = Logger.debug(fn -> "Not getting events" end)
        {core, callbacks}
    end
  end

  defp schedule_get_events(interval) do
    :timer.send_interval(interval, self(), :sync)
  end
end
