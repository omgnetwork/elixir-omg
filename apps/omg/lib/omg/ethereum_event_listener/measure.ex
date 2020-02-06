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

defmodule OMG.EthereumEventListener.Measure do
  @moduledoc """
  Counting business metrics sent to Datadog.
  We don't want to pattern match on :ok to Datadog because the connection
  towards the statsd client can be intermittent and sending would be unsuccessful and that
  would trigger the removal of telemetry handler. But because we have monitors in place,
  that eventually recover the connection to Statsd handlers wouldn't exist anymore and metrics
  wouldn't be published.
  """

  import OMG.Status.Metric.Event, only: [name: 2]

  alias OMG.Status.Metric.Datadog
  alias OMG.Status.Metric.Tracer

  @supported_events [
    [:process, OMG.EthereumEventListener],
    [:trace, OMG.EthereumEventListener],
    [:trace, OMG.EthereumEventListener.Core]
  ]
  def supported_events(), do: @supported_events

  def handle_event([:process, OMG.EthereumEventListener], %{events: events}, state, _config) do
    _ = Datadog.gauge(name(state.service_name, :events), length(events))
  end

  def handle_event([:process, OMG.EthereumEventListener], %{}, state, _config) do
    value =
      self()
      |> Process.info(:message_queue_len)
      |> elem(1)

    _ = Datadog.gauge(name(state.service_name, :message_queue_len), value)
  end

  def handle_event([:trace, _], %{}, state, _config) do
    Tracer.update_top_span(service: state.service_name, tags: [])
  end
end
