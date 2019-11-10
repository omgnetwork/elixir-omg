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

defmodule OMG.WatcherSecurity.Eventer do
  @moduledoc """
  Imperative shell for handling events, which are exposed to the client of the Watcher application.
  All handling of event triggers that are processed, transformed into events and pushed to the internal EventBus where they get consumed by Phoenix Eventer module.

  The event triggers (which get later translated into specific events/topics etc.) arrive here via `OMG.Bus`

  See `OMG.EventerAPI` for the API to the GenServer
  """

  alias OMG.WatcherSecurity.Eventer.Core

  require Logger
  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ### Server

  use GenServer

  def init(:ok) do
    # `link: true` because we want the `Eventer` to restart and resubscribe, if the bus crashes
    :ok = OMG.Bus.subscribe("events", link: true)

    {:ok, _} =
      :timer.send_interval(Application.fetch_env!(:omg_watcher, :metrics_collection_interval), self(), :send_metrics)

    _ = Logger.info("Started #{inspect(__MODULE__)}")
    {:ok, Core.init()}
  end

  def handle_info({:internal_event_bus, :preprocess_emit_events, event_triggers}, state) do
    :ok =
      event_triggers
      |> Core.pair_events_with_topics()
      |> do_broadcast()

    {:noreply, state}
  end

  def handle_info(:send_metrics, state) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, state)
    {:noreply, state}
  end

  # sending events to OMG.WatcherRPC.BroadcastEvent
  defp do_broadcast(event_triggers) do
    OMG.Bus.broadcast("broadcast_event", {:emit_events, event_triggers})
  end
end
