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

defmodule OMG.State.Measure do
  @moduledoc """
  Counting business metrics sent to Datadog
  """

  import OMG.Status.Metric.Event, only: [name: 1]

  alias OMG.State.Core
  alias OMG.State.MeasurementCalculation
  alias OMG.Status.Metric.Datadog

  @supported_events [
    [:process, OMG.State],
    [:pending_transactions, OMG.State.Core],
    [:block_transactions, OMG.State.Core]
  ]
  def supported_events(), do: @supported_events

  def handle_event([:process, OMG.State], _, %Core{} = state, _config) do
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

  def handle_event([:pending_transactions, OMG.State.Core], %{new_tx: _new_tx}, _, _config) do
    _ = Datadog.increment(name(:pending_transactions), 1)
  end

  def handle_event([:block_transactions, OMG.State.Core], %{txs: txs}, _, _config) do
    _ = Datadog.gauge(name(:block_transactions), Enum.count(txs))
  end
end
