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
use OMG.Utils.LoggerExt

defmodule OMG.ChildChain.Transaction.Metric.Submit do
  @moduledoc """
  A module for creating and tagging a metric from telemetry event data and metadata.

  Encapsulates the logic for:
    1. creating a metric from a telemetry event's data, metadata and config
    2. tagging the metric with metric-specific tags
  """

  @transaction_submit_event [:transaction, :submit]
  def transaction_submit_event, do: @transaction_submit_event

  # The tag values for 'transaction_submit' events.
  @success_value "success"
  @failure_value "failure"

  def measure(data, _metadata, config) do
    metric_name = telemetry_event_name_to_dd_metric_name(@transaction_submit_event)

    {metric_name, 1, tags(metric_name, data.result, config)}
  end

  defp tags(metric_name, result, config) do
    tag_value = if result == :ok do
      @success_value
    else
      @failure_value
    end

    ["#{metric_name}:#{tag_value}" | config.tags]
  end

  # TODO(PR) find a home for this function. it will likely be needed for other metrics.
  # `apps/omg_status/lib/omg_status/metric/datadog.ex` or in that directory might be a
  # good area for this.
  #
  # converts a telemetry 'event name' atom list into a dotted string 'metric name'.
  defp telemetry_event_name_to_dd_metric_name(event_name) do
    # TODO(PR) decide on business-metric naming and namespacing
    Enum.join(event_name, ".")
  end
end
