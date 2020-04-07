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

defmodule OMG.Watcher.DatadogEvent.ContractEventConsumer do
  @moduledoc """
  Subscribes to new events from EthereumEventListeners and pushes them to Datadog
  Integrated with the help of: https://docs.datadoghq.com/api/?lang=bash#post-an-event
  Most things from the doc doesn't work. Either because Statix doesn't work or Datadog.
  Date_happened, aggregation_key, source_type_name doesn't seem to appear in Events list.
  Hence we transform everything into a tag.
  """

  require Logger
  alias OMG.Watcher.DatadogEvent.Encode

  @doc """
  Returns child_specs for the given `EventConsumer`, to be included e.g. in Supervisor's children.
  """
  # sobelow_skip ["DOS.StringToAtom"]
  @spec prepare_child(keyword()) :: %{id: atom(), start: tuple()}
  def prepare_child(opts \\ []) do
    id =
      case Keyword.fetch!(opts, :topic) do
        {origin, topic_name} -> "#{origin}:#{topic_name}_worker"
        other -> "#{other}_worker"
      end

    %{
      id: String.to_atom(id),
      start: {__MODULE__, :start_link, [opts]},
      shutdown: :brutal_kill,
      type: :worker
    }
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  ### Server

  use GenServer

  def init(args) do
    publisher = Keyword.fetch!(args, :publisher)
    topic = Keyword.fetch!(args, :topic)
    release = Keyword.fetch!(args, :release)
    current_version = Keyword.fetch!(args, :current_version)
    :ok = OMG.Bus.subscribe(topic, link: true)

    _ = Logger.info("Started #{inspect(__MODULE__)} for event #{topic}")
    {:ok, %{publisher: publisher, release: release, current_version: current_version}}
  end

  def handle_info({:internal_event_bus, :enqueue_block, _omg_block}, state) do
    # ignore for now
    {:noreply, state}
  end

  @doc """
    Listens to events via OMG BUS and send them off
    the assumption is all events are of the same type
  """
  def handle_info({:internal_event_bus, :data, data}, state) do
    %{event_signature: event_signature} = hd(data)
    [event_name, _] = String.split(event_signature, "(")
    aggregation_key = :root_chain
    timestamp = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    options = tags(aggregation_key, state.release, state.current_version, timestamp)
    title = "#{event_name}"
    message = "#{inspect(Encode.make_it_readable!(data))} - Timestamp: #{timestamp}"

    :ok = apply(state.publisher, :event, create_event_data(title, message, options))

    {:noreply, state}
  end

  defp create_event_data(title, message, options) do
    [title, message, options]
  end

  # https://docs.datadoghq.com/api/?lang=bash#api-reference
  defp tags(aggregation_key, release, current_version, _timestamp) do
    [
      {:aggregation_key, aggregation_key},
      {:tags, ["#{aggregation_key}", "#{release}", "vsn-#{current_version}"]},
      {:alert_type, "success"}
      # {:timestamp, timestamp}
    ]
  end
end
