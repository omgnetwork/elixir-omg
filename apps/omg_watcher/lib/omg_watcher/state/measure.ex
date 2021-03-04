# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Watcher.State.Measure do
  @moduledoc """
  Counting business metrics sent to Datadog
  """

  import OMG.Status.Metric.Event, only: [name: 1]
  alias OMG.Status.Metric.Datadog
  alias OMG.Watcher.State
  alias OMG.Watcher.State.Core
  alias OMG.Watcher.State.MeasurementCalculation

  @supported_events [
    [:process, State],
    [:pending_transactions, Core],
    [:block_transactions, Core]
  ]
  def supported_events(), do: @supported_events

  def handle_event([:process, State], _, %Core{} = state, _config) do
    execute = fn ->
      try do
        Enum.each(MeasurementCalculation.calculate(state), fn
          {key, value} -> _ = Datadog.gauge(name(key), value)
          {key, value, metadata} -> _ = Datadog.gauge(name(key), value, tags: [metadata])
        end)
      rescue
        _e in ArgumentError ->
          # This exception occurs when we run without datadog (statix).
          # In normal scenarios, telemetry would get detached but because this is a spawned proces...
          :ok
      end
    end

    # TODO proper fix! this is a very hackish approach to get measurements off the back
    # of OMG State
    _ = Task.start(execute)
    :ok
  end

  def handle_event([:pending_transactions, Core], %{new_tx: _new_tx}, _, _config) do
    _ = Datadog.increment(name(:pending_transactions), 1)
  end

  def handle_event([:block_transactions, Core], %{txs: txs}, _, _config) do
    _ = Datadog.gauge(name(:block_transactions), Enum.count(txs))
  end
end
