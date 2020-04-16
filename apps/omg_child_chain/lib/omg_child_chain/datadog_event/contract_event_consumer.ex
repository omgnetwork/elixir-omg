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

defmodule OMG.ChildChain.DatadogEvent.ContractEventConsumer do
  @moduledoc """
  Subscribes to new events from EthereumEventListeners and BlockGetter and pushes them to Datadog
  Integrated with the help of: https://docs.datadoghq.com/api/?lang=bash#post-an-event
  """

  require Logger
  alias OMG.ChildChain.DatadogEvent.Encode
  use GenServer

  @doc """
  Returns child_specs for the given `EventConsumer`, to be included e.g. in Supervisor's children.
  Mandatory params are in Keyword form:
  - :publisher is Module that implements a function `event/3` (title, message, option). It's purpose is to forward
  events to a collector (for example, Datadog)
  - :topic is a OMG.Bus topic from which this process recieves data and sends them to the publisher and onwards
  - :release is the mode this current process is runing under (for example, currently we support watcher, child chain or watcher info)
  - :current_version is semver of the current code
  """
  # sobelow_skip ["DOS.StringToAtom"]
  @spec prepare_child(keyword()) :: %{id: atom(), start: tuple()}
  def prepare_child(opts) do
    {:root_chain, topic_name} = Keyword.fetch!(opts, :topic)

    %{
      id: String.to_atom("root_chain:#{topic_name}_worker"),
      start: {__MODULE__, :start_link, [opts]},
      shutdown: :brutal_kill,
      type: :worker
    }
  end

  @doc """
  args are documented above
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  ### Server

  @doc """
  args are documented in prepare_child.
  """
  def init(args) do
    publisher = Keyword.fetch!(args, :publisher)
    {:root_chain, event_name} = topic = Keyword.fetch!(args, :topic)
    release = Keyword.fetch!(args, :release)
    current_version = Keyword.fetch!(args, :current_version)
    :ok = OMG.Bus.subscribe(topic, link: true)

    _ = Logger.info("Started #{inspect(__MODULE__)} for event root_chain:#{event_name}")
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

    Enum.each(data, fn(ev) ->
      message = "[#{inspect(Encode.make_it_readable!(ev))}] - Timestamp: #{timestamp}"
      :ok = apply(state.publisher, :event, create_event_data(title, message, options))
    end)

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
      {:alert_type, "info"}
    ]
  end
end
