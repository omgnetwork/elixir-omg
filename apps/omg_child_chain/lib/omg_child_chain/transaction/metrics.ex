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

defmodule OMG.ChildChain.Transaction.Metrics do
  @moduledoc """
  A Telemetry event listener for transaction events. It receives Telemetry
  events and publishes them as tagged metrics to DataDog.

  Encapsulates the logic for:
    1. creating a handler for handling Telemetry events
    2. receiving event data from Telemetry
    3. delegating received event data to a metric handler for Telemetry
       event to DataDog metric conversion
    4. publishing the Datadog metric
  """
  alias OMG.ChildChain.Transaction.Metric.Submit
  alias OMG.Status.Metric.Datadog

  # A unique identifier for this handler that can be attached to one or more events.
  @handler_id "metrics-transaction-events-handler"

  # A list of each telemetry event the handler listens to. Each event is mapped to a `metric_module`
  # for measurement and `publisher` for publishing the data.
  @transaction_event_mappings %{
    Submit.transaction_submit_event() => %{measure: &Submit.measure/3, publish: &Datadog.increment/3}
  }
  
  # A list of transaction-related telemetry events.
  @transaction_events Map.keys(@transaction_event_mappings)

  # Returns a handler for handling of transaction-related events.
  def events_handler(config) do
    [@handler_id, @transaction_events, &handle_event/4, config]
  end

  # Emits a telemetry event that a transaction has been submitted.
  # Emitted event: `{[:transaction, :submit], %{data: %{blknum: 1, txhash: 0, txindex: 0}, result: :ok}, %{}}`
  def emit_transaction_submit_event({result, _} = event_data, event_metadata \\ %{}) do
    case event_data do
      {:ok, data} ->
        # TODO(Jacob) clean
        IO.puts("Metrics.emit_transaction_submit_event(): sending: #{inspect({Submit.transaction_submit_event(), %{result: result, data: data}, event_metadata})}")

        :ok = :telemetry.execute(Submit.transaction_submit_event(), %{result: result, data: data}, event_metadata)
      
      {:error, error_data} ->
        # TODO(Jacob) clean
        IO.puts("Metrics.emit_transaction_submit_event(): sending: #{inspect({Submit.transaction_submit_event(), %{result: result, error_data: error_data}, event_metadata})}")

        :ok = :telemetry.execute(Submit.transaction_submit_event(), %{result: result, data: error_data}, event_metadata)
    end

    event_data
  end

  # default behavior for `handle_event/4`
  # Example received event:
  #    `{[:transaction, :submit], %{data: %{blknum: 1, txhash: 0, txindex: 0}, result: :ok}, %{tags: [..]}}`
  def handle_event(event_name, data, metadata, config) do when event_name in @transaction_events do
    IO.puts("Metrics.handle_event(): receiving: #{inspect({event_name, data, metadata, config})}")

    {metric, value, tags} = @transaction_event_mappings[event_name].measure.(data, metadata, config)

    @transaction_event_mappings[event_name].publish.(metric, value, tags)
  end
end
