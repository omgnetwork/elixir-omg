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

defmodule OMG.EthereumEventListener.Measure do
  @moduledoc """
  Counting business metrics sent to DataDog
  """

  import OMG.Status.Metric.Event, only: [name: 2]

  alias OMG.Status.Metric.Datadog
  alias OMG.Status.Metric.Tracer

  @supported_events [
    [:process, OMG.EthereumEventListener],
    [:process, OMG.EthereumEventListener.Core],
    [:trace, OMG.EthereumEventListener],
    [:trace, OMG.EthereumEventListener.Core]
  ]
  def supported_events, do: @supported_events

  def handle_event([:process, OMG.EthereumEventListener.Core], %{events: events}, state, _config) do
    :ok = Datadog.gauge(name(state.service_name, :events), length(events))
  end

  def handle_event([:process, OMG.EthereumEventListener], %{}, state, _config) do
    value =
      self()
      |> Process.info(:message_queue_len)
      |> elem(1)

    :ok = Datadog.gauge(name(state.service_name, :message_queue_len), value)
  end

  def handle_event([:trace, _], %{}, state, _config) do
    # TODO change to compiler flags once we're running releases
    is_child_chain =
      Enum.any?(Application.started_applications(), fn
        {:omg_child_chain, _, _} -> true
        {_, _version, _desc} -> false
      end)

    if is_child_chain do
      service = service(:child_chain, state.service_name)
      Tracer.update_top_span(service: service, tags: [])
    else
      service = service(:watcher, state.service_name)
      Tracer.update_top_span(service: service, tags: [])
    end
  end

  defp service(app, service_name) do
    :erlang.binary_to_atom(
      <<:erlang.atom_to_binary(app, :utf8)::binary, "_", :erlang.atom_to_binary(service_name, :utf8)::binary>>,
      :utf8
    )
  end
end
