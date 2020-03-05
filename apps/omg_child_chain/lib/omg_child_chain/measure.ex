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

defmodule OMG.ChildChain.Measure do
  @moduledoc """
  Counting business metrics sent to Datadog
  """
  alias OMG.Status.Metric.Datadog

  # Configuration of global tags and metric name prefixes can be added in the apps config.exs file, like so:
  # ```
  # config :statix,
  #   prefix: "omg.childchain",
  #   tags: ["application:childchain"]
  # ```

  @txn_submission_subprefix [:transaction, :submission]

  @txn_submission_submitted @txn_submission_subprefix ++ [:submitted]
  def txn_submission_submitted(), do: @txn_submission_submitted

  @txn_submission_succeeded @txn_submission_subprefix ++ [:succeeded]
  def txn_submission_succeeded(), do: @txn_submission_succeeded

  @txn_submission_failed @txn_submission_subprefix ++ [:failed]
  def txn_submission_failed(), do: @txn_submission_failed

  @supported_events [@txn_submission_submitted, @txn_submission_succeeded, @txn_submission_failed]
  def supported_events(), do: @supported_events

  @increment 1
  
  def measurements(), do: %{increment: @increment}

  def measurements(measurements) when is_map(measurements), do: Map.get(measurements, :increment, 1)

  def handle_event(@txn_submission_submitted, measurements, _event_metadata, _config) do
    Datadog.increment(event_name_to_metric_name(@txn_submission_submitted), measurements(measurements), tags: [])
  end

  def handle_event(@txn_submission_succeeded, measurements, _event_metadata, _config) do
    Datadog.increment(event_name_to_metric_name(@txn_submission_succeeded), measurements(measurements), tags: [])
  end

  def handle_event(@txn_submission_failed, measurements, _event_metadata, _config) do
    Datadog.increment(event_name_to_metric_name(@txn_submission_failed), measurements(measurements), tags: [])
  end

  defp event_name_to_metric_name(event_atoms) do
    event_atoms
    |> Enum.map(fn event_atom -> to_string(event_atom) end)
    |> Enum.reduce(fn event_name_part, metric_name -> metric_name <> "." <> event_name_part end)
  end
end
