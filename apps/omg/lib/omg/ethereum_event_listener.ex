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

defmodule OMG.EthereumEventListener do
  @moduledoc """
  GenServer running the listener, see `OMG.EthereumEventListener.Core`
  """

  alias OMG.EthereumEventListener.Core
  alias OMG.EthereumEventListener.Preprocessor
  alias OMG.RootChainCoordinator
  alias OMG.RootChainCoordinator.SyncGuide

  use GenServer
  use Spandex.Decorators
  use OMG.Utils.LoggerExt

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
  See `handle_continue/2` for the required keyword arguments
  """
  @spec prepare_child(keyword()) :: %{id: atom(), start: tuple()}
  def prepare_child(opts \\ []) do
    name = Keyword.fetch!(opts, :service_name)
    %{id: name, start: {OMG.EthereumEventListener, :start_link, [Map.new(opts)]}, shutdown: :brutal_kill, type: :worker}
  end

  ### Server

  def init(init) do
    {:ok, init, {:continue, :setup}}
  end

  def handle_continue(:setup, %{
        synced_height_update_key: update_key,
        service_name: service_name,
        get_events_callback: get_events_callback,
        process_events_callback: process_events_callback
      }) do
    _ = Logger.info("Starting #{inspect(__MODULE__)} for #{service_name}.")
    {:ok, contract_deployment_height} = OMG.Eth.RootChain.get_root_deployment_height()
    {:ok, last_event_block_height} = OMG.DB.get_single_value(update_key)
    # we don't need to ever look at earlier than contract deployment
    last_event_block_height = max(last_event_block_height, contract_deployment_height)
    {initial_state, height_to_check_in} = Core.init(update_key, service_name, last_event_block_height)

    callbacks_map = %{
      get_ethereum_events_callback: get_events_callback,
      process_events_callback: process_events_callback
    }

    {:ok, _} = schedule_get_events()
    :ok = RootChainCoordinator.check_in(height_to_check_in, service_name)
    {:ok, _} = :timer.send_interval(Application.fetch_env!(:omg, :metrics_collection_interval), self(), :send_metrics)

    _ = Logger.info("Started #{inspect(__MODULE__)} for #{service_name}, synced_height: #{inspect(height_to_check_in)}")

    {:noreply, {initial_state, callbacks_map}}
  end

  def handle_info(:send_metrics, {core, _callbacks} = state) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, core)
    {:noreply, state}
  end

  @decorate trace(service: :ethereum_event_listener, type: :backend)
  def handle_info(:sync, {%Core{} = core, _callbacks} = state) do
    :ok = :telemetry.execute([:trace, __MODULE__], %{}, core)

    case RootChainCoordinator.get_sync_info() do
      :nosync ->
        :ok = RootChainCoordinator.check_in(Core.get_height_to_check_in(core), core.service_name)
        {:ok, _} = schedule_get_events()
        {:noreply, state}

      sync_info ->
        new_state = sync_height(state, sync_info)
        {:ok, _} = schedule_get_events()
        {:noreply, new_state}
    end
  end

  @decorate span(service: :ethereum_event_listener, type: :backend, name: "sync_height/2")
  defp sync_height(
         {%Core{} = core, callbacks},
         %SyncGuide{sync_height: sync_height} = sync_info
       ) do
    {:ok, events, db_updates, height_to_check_in, new_state} =
      Core.get_events_range_for_download(core, sync_info)
      |> maybe_update_event_cache(callbacks.get_ethereum_events_callback)
      |> Core.get_events(sync_height)

    :ok = :telemetry.execute([:process, __MODULE__], %{events: events}, core)
    IO.inspect("yolo events #{inspect(events)}")

    {:ok, db_updates_from_callback} =
      events
      |> Enum.map(&Preprocessor.apply/1)
      |> publish_data()
      |> callbacks.process_events_callback.()

    :ok = OMG.DB.multi_update(db_updates ++ db_updates_from_callback)
    :ok = RootChainCoordinator.check_in(height_to_check_in, core.service_name)

    {new_state, callbacks}
  end

  @decorate span(service: :ethereum_event_listener, type: :backend, name: "maybe_update_event_cache/2")
  defp maybe_update_event_cache({:get_events, {from, to}, state_with_cache}, get_ethereum_events_callback) do
    {:ok, new_events} = get_ethereum_events_callback.(from, to)
    Core.add_new_events(state_with_cache, new_events)
  end

  @decorate span(service: :ethereum_event_listener, type: :backend, name: "maybe_update_event_cache/2")
  defp maybe_update_event_cache({:dont_fetch_events, state}, _callback), do: state

  defp schedule_get_events do
    Application.fetch_env!(:omg, :ethereum_events_check_interval_ms)
    |> :timer.send_after(self(), :sync)
  end

  defp publish_data([%{event_signature: event_signature} | _] = data) do
    IO.inspect(data)
    # String.split("DepositCreated(address,uint256,address,uint256)", "(")
    [event_signature, _] = String.split(event_signature, "(")
    IO.inspect(event_signature)
    :ok = OMG.Bus.direct_local_broadcast(event_signature, {:data, data})
    data
  end

  defp publish_data([] = data) do
    data
  end
end
