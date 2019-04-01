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

defmodule OMG.Watcher.Eventer do
  @moduledoc """
  Imperative shell for handling events, which are exposed to the client of the Watcher application.
  All handling of event triggers that are processed, transformed into events and pushed to Phoenix Channels
  for their respective topics is intended to be done here.

  The event triggers (which get later translated into specific events/topics etc.) arrive here via `OMG.InternalEventBus`

  See `OMG.EventerAPI` for the API to the GenServer
  """

  alias OMG.Watcher.Eventer.Core
  alias OMG.Watcher.Recorder
  alias OMG.Watcher.Web.Endpoint
  alias Utils.JsonRPC.Response
  ### Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ### Server

  use GenServer

  def init(:ok) do
    {:ok, _} = Recorder.start_link(%Recorder{name: __MODULE__.Recorder, parent: self()})

    # `link: true` because we want the `Eventer` to restart and resubscribe, if the bus crashes
    :ok = OMG.InternalEventBus.subscribe("events", link: true)

    {:ok, nil}
  end

  def handle_info({:internal_event_bus, :emit_events, event_triggers}, nil) do
    event_triggers
    |> Core.pair_events_with_topics()
    |> Enum.each(fn {topic, event_name, event} ->
      :ok =
        Endpoint.broadcast!(
          topic,
          event_name,
          event |> Response.sanitize()
        )
    end)

    {:noreply, nil}
  end
end
