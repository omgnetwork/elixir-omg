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

defmodule OMG.EthereumEventListener do
  @moduledoc """
  GenServer running the listener.

  Periodically fetches events made on dynamically changing block range
  from the root chain contract and feeds them to a callback.

  It is **not** responsible for figuring out which ranges of Ethereum blocks are eligible to scan and when, see
  `OMG.RootChainCoordinator` for that.
  The `OMG.RootChainCoordinator` provides the `SyncGuide` that indicates what's eligible to scan, taking into account:
   - finality margin
   - mutual ordering and dependencies of various types of Ethereum events to be respected.

  It **is** responsible for processing all events from all blocks and processing them only once.

  It accomplishes that by keeping a persisted value in `OMG.DB` and its state that reflects till which Ethereum height
  the events were processed (`synced_height`).
  This `synced_height` is updated after every batch of Ethereum events get successfully consumed by
  `callbacks.process_events_callback`, as called in `sync_height/2`, together with all the `OMG.DB` updates this
  callback returns, atomically.
  The key in `OMG.DB` used to persist `synced_height` is defined by the value of `synced_height_update_key`.

  What specific Ethereum events it fetches, and what it does with them is up to predefined `callbacks`.

  See `OMG.EthereumEventListener.Core` for the implementation of the business logic for the listener.
  """
  use GenServer
  use Spandex.Decorators
  use OMG.Utils.LoggerExt

  alias OMG.EthereumEventListener.Core
  alias OMG.RootChainCoordinator

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
  Returns child_specs for the given `EthereumEventListener` setup, to be included e.g. in Supervisor's children.
  See `handle_continue/2` for the required keyword arguments.
  """
  @spec prepare_child(keyword()) :: %{id: atom(), start: tuple()}
  def prepare_child(opts \\ []) do
    name = Keyword.fetch!(opts, :service_name)
    %{id: name, start: {OMG.EthereumEventListener, :start_link, [Map.new(opts)]}, shutdown: :brutal_kill, type: :worker}
  end

  ### Server

  @doc """
  Initializes the GenServer state, most work done in `handle_continue/2`.
  """
  def init(init) do
    {:ok, init, {:continue, :setup}}
  end

  @doc """
  Reads the status of listening (till which Ethereum height were the events processed) from the `OMG.DB` and initializes
  the logic `OMG.EthereumEventListener.Core` with it. Does an initial `OMG.RootChainCoordinator.check_in` with the
  Ethereum height it last stopped on. Next, it continues to monitor and fetch the events as usual.
  """
  def handle_continue(
        :setup,
        %{
          contract_deployment_height: contract_deployment_height,
          synced_height_update_key: update_key,
          service_name: service_name,
          get_events_callback: get_events_callback,
          process_events_callback: process_events_callback,
          metrics_collection_interval: metrics_collection_interval,
          ethereum_events_check_interval_ms: ethereum_events_check_interval_ms
        }
      ) do
    _ = Logger.info("Starting #{inspect(__MODULE__)} for #{service_name}.")

    {:ok, last_event_block_height} = OMG.DB.get_single_value(update_key)

    # we don't need to ever look at earlier than contract deployment
    last_event_block_height = max(last_event_block_height, contract_deployment_height)

    {initial_state, height_to_check_in} =
      Core.init(update_key, service_name, last_event_block_height, ethereum_events_check_interval_ms)

    callbacks = %{
      get_ethereum_events_callback: get_events_callback,
      process_events_callback: process_events_callback
    }

    {:ok, _} = schedule_get_events(ethereum_events_check_interval_ms)
    :ok = RootChainCoordinator.check_in(height_to_check_in, service_name)
    {:ok, _} = :timer.send_interval(metrics_collection_interval, self(), :send_metrics)

    _ = Logger.info("Started #{inspect(__MODULE__)} for #{service_name}, synced_height: #{inspect(height_to_check_in)}")

    {:noreply, {initial_state, callbacks}}
  end

  def handle_info(:send_metrics, {state, callbacks}) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, state)
    {:noreply, {state, callbacks}}
  end

  @doc """
  Main worker function, called on a cadence as initialized in `handle_continue/2`.

  Does the following:
   - asks `OMG.RootChainCoordinator` about how to sync, with respect to other services listening to Ethereum
   - (`sync_height/2`) figures out what is the suitable range of Ethereum blocks to download events for
   - (`sync_height/2`) if necessary fetches those events to the in-memory cache in `OMG.EthereumEventListener.Core`
   - (`sync_height/2`) executes the related event-consuming callback with events as arguments
   - (`sync_height/2`) does `OMG.DB` updates that persist the processes Ethereum height as well as whatever the
      callbacks returned to persist
   - (`sync_height/2`) `OMG.RootChainCoordinator.check_in` to tell the rest what Ethereum height was processed.
  """
  @decorate trace(service: :ethereum_event_listener, type: :backend)
  def handle_info(:sync, {state, callbacks}) do
    :ok = :telemetry.execute([:trace, __MODULE__], %{}, state)

    case RootChainCoordinator.get_sync_info() do
      :nosync ->
        :ok = RootChainCoordinator.check_in(state.synced_height, state.service_name)
        {:ok, _} = schedule_get_events(state.ethereum_events_check_interval_ms)
        {:noreply, {state, callbacks}}

      sync_info ->
        new_state = sync_height(state, callbacks, sync_info)
        {:ok, _} = schedule_get_events(state.ethereum_events_check_interval_ms)
        {:noreply, {new_state, callbacks}}
    end
  end

  # see `handle_info/2`, clause for `:sync`
  @decorate span(service: :ethereum_event_listener, type: :backend, name: "sync_height/3")
  defp sync_height(state, callbacks, sync_guide) do
    {events, new_state} =
      state
      |> Core.calc_events_range_set_height(sync_guide)
      |> get_events(callbacks.get_ethereum_events_callback)

    db_update = [{:put, new_state.synced_height_update_key, new_state.synced_height}]
    :ok = :telemetry.execute([:process, __MODULE__], %{events: events}, new_state)

    {:ok, db_updates_from_callback} = callbacks.process_events_callback.(events)
    :ok = publish_events(events)
    :ok = OMG.DB.multi_update(db_update ++ db_updates_from_callback)
    :ok = RootChainCoordinator.check_in(new_state.synced_height, new_state.service_name)

    new_state
  end

  defp get_events({{from, to}, state}, get_events_callback) do
    {:ok, new_events} = get_events_callback.(from, to)
    {new_events, state}
  end

  defp get_events({:dont_fetch_events, state}, _callback) do
    {[], state}
  end

  defp schedule_get_events(ethereum_events_check_interval_ms) do
    :timer.send_after(ethereum_events_check_interval_ms, self(), :sync)
  end

  defp publish_events([%{event_signature: event_signature} | _] = data) do
    [event_signature, _] = String.split(event_signature, "(")

    {:root_chain, event_signature}
    |> OMG.Bus.Event.new(:data, data)
    |> OMG.Bus.direct_local_broadcast()
  end

  defp publish_events([]), do: :ok
end
