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

defmodule OMG.ChildChain.Transaction.Metric.Submit do
  @moduledoc """
  A module for creating and tagging a 'transaction.submit' metric from
  Telemetry event data and metadata.

  Encapsulates the logic for:
    1. creating a metric from a Telemetry event's data, metadata and config
    2. tagging the metric with metric-specific tags
  """

  # The tag values for this metric
  @success_value "success"
  @failure_value "failure"

  @doc """
  Returns the name of the Telemetry event mapped to this metric. A Telemetry event name
  is represented as a list of atoms.
  """
  @transaction_submit_event [:transaction, :submit]
  def transaction_submit_event(), do: @transaction_submit_event

  @metric_name Enum.join(@transaction_submit_event, ".")

  @doc """
  Creates a new metric from telemetry event data, metadata and a config map.
  """
  def measure(data, _metadata, config \\ %{}) do
    {@metric_name, 1, tags(data.result, config)}
  end

  defp tags(result, config) do
    tag_value =
      if result == :ok do
        @success_value
      else
        @failure_value
      end

    case Map.get(config, :tags, nil) do
      nil -> ["#{@metric_name}:#{tag_value}"]
      tags -> ["#{@metric_name}:#{tag_value}" | tags]
    end
  end
end
