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

defmodule LoadTest.Service.Metrics do
  @moduledoc """
  Functions for aggregating metrics.
  """

  alias LoadTest.Service.Datadog
  alias LoadTest.Service.Datadog.API

  def run_with_metrics(func, property) do
    case Application.get_env(:load_test, :record_metrics) do
      true -> do_run_with_metrics(func, property)
      false -> func.()
    end
  end

  def assert_metrics(start_datetime, end_datetime) do
    env = :statix |> Application.get_env(:tags) |> List.first()

    API.assert_metrics(env, start_datetime, end_datetime)
  end

  defp do_run_with_metrics(func, property) do
    {time, result} = :timer.tc(func)

    time_ms = time / 1_000

    case result do
      {:ok, _} -> record_success(property, time_ms)
      :ok -> record_success(property, time_ms)
      _ -> record_failure(property, time_ms)
    end

    result
  end

  defp record_success(property, time) do
    record_datadog(property, time, "_success")
  end

  defp record_failure(property, time) do
    record_datadog(property, time, "_failure")
  end

  defp record_datadog(property, time, postfix) do
    property_name = property <> postfix
    total_property_name = property <> "_count"

    :ok = Datadog.gauge(property_name, time, tags: tags())

    increment_counter(property_name <> "_count")
    increment_counter(total_property_name)
  end

  defp increment_counter(property) do
    :ok = Datadog.increment(property, 1, tags: tags())
  end

  defp tags() do
    Application.get_env(:statix, :tags)
  end
end
