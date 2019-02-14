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
  GenServer running the listener, see `OMG.API.EthereumEventListener`
  """

  alias OMG.API.EthereumEventListener.Core
  alias OMG.API.RootChainCoordinator
  alias OMG.API.RootChainCoordinator.SyncData

  use OMG.API.LoggerExt

  @type config() :: %{
          block_finality_margin: non_neg_integer,
          synced_height_update_key: atom,
          service_name: atom,
          # maps a pair denoting eth height range to a list of ethereum events
          get_events_callback: (non_neg_integer, non_neg_integer -> {:ok, [map]}),
          # maps a list of ethereum events to a list of `db_updates` to send to `OMG.DB`
          process_events_callback: ([any] -> {:ok, [tuple]})
        }

  ### Client

  @spec start_link(config()) :: GenServer.on_start()
  def start_link(config) do
    %{service_name: name} = config
    GenServer.start_link(__MODULE__, config, name: name)
  end

  @doc """
  Returns child_specs for the given `EthereumEventListener` setup, to be included e.g. in Supervisor's children
  See `init/1` for the required keyword arguments
  """
  @spec prepare_child(keyword()) :: %{id: atom(), start: tuple()}
  def prepare_child(opts \\ []) do
    name = Keyword.fetch!(opts, :service_name)
    %{id: name, start: {OMG.API.EthereumEventListener, :start_link, [Map.new(opts)]}}
  end

  ### Server

  use GenServer

  def init(%{
        synced_height_update_key: update_key,
        service_name: service_name,
        get_events_callback: get_events_callback,
        process_events_callback: process_events_callback
      }) do
    _ = Logger.info("Starting EthereumEventListener for #{service_name}")

    {:ok, contract_deployment_height} = OMG.Eth.RootChain.get_root_deployment_height()
    {:ok, last_event_block_height} = OMG.DB.get_single_value(update_key)
    # we don't need to ever look at earlier than contract deployment
    last_event_block_height = max(last_event_block_height, contract_deployment_height)
    {initial_state, height_to_check_in} = Core.init(update_key, service_name, last_event_block_height)

    callbacks_map = %{
      get_ethereum_events_callback: get_events_callback,
      process_events_callback: process_events_callback
    }

    {:ok, _} = schedule_get_events(Application.fetch_env!(:omg_api, :ethereum_status_check_interval_ms))
    :ok = RootChainCoordinator.check_in(height_to_check_in, service_name)
    {:ok, {initial_state, callbacks_map}}
  end

  def handle_info(:sync, {core, _callbacks} = state) do
    case RootChainCoordinator.get_sync_info() do
      :nosync ->
        :ok = RootChainCoordinator.check_in(core.synced_height, core.service_name)
        {:noreply, state}

      sync_info ->
        new_state = sync_height(state, sync_info)
        {:noreply, new_state}
    end
  end

  defp sync_height({state, callbacks}, %SyncData{sync_height: sync_height} = sync_info) do
    state =
      case Core.get_events_range_for_download(state, sync_info) do
        {:get_events, {from, to}, state} ->
          {:ok, new_events} = callbacks.get_ethereum_events_callback.(from, to)
          Core.add_new_events(state, new_events)

        {:dont_fetch_events, state} ->
          state
      end

    {:ok, events, db_updates, height_to_check_in, state} = Core.get_events(state, sync_height)
    {:ok, db_updates_from_callback} = callbacks.process_events_callback.(events)
    :ok = OMG.DB.multi_update(db_updates ++ db_updates_from_callback)
    :ok = RootChainCoordinator.check_in(height_to_check_in, state.service_name)

    {state, callbacks}
  end

  defp schedule_get_events(interval) do
    :timer.send_interval(interval, self(), :sync)
  end
end
