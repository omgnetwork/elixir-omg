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

defmodule OMG.WatcherRPC.BroadcastEvent do
  @moduledoc """
  Imperative shell for handling events, which are exposed to the client of the Watcher application.
  All handling of event triggers that are processed, transformed into events and pushed to Phoenix Channels
  for their respective topics is intended to be done here.

  The event triggers (which get later translated into specific events/topics etc.) arrive here via `OMG.InternalEventBus`

  See `OMG.EventerAPI` for the API to the GenServer
  """

  alias OMG.Utils.HttpRPC.Response
  alias OMG.WatcherRPC.Web.Endpoint
  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ### Server

  use GenServer

  def init(:ok) do
    # `link: true` because we want the `BroadcastEvent` to restart and resubscribe, if the bus crashes
    :ok = OMG.InternalEventBus.subscribe("broadcast_event", link: true)

    {:ok, nil}
  end

  def handle_info({:internal_event_bus, :emit_events, event_triggers}, nil) do
    Enum.each(event_triggers, fn {topic, event_name, event} ->
      :ok =
        Endpoint.broadcast!(
          topic,
          event_name,
          Response.sanitize(event)
        )
    end)

    {:noreply, nil}
  end
end
