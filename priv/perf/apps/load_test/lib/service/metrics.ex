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
  use Histogrex

  template(:metrics, min: 1, max: 100_000_000, precision: 2)

  @percentiles [
    10.0,
    20.0,
    30.0,
    40.0,
    50.0,
    60.0,
    75.0,
    80.0,
    85.0,
    90.0,
    95.0,
    99.0,
    99.9,
    99.99,
    99.999
  ]

  def run_with_metrics(func, property) do
    case Application.get_env(:load_test, :record_metrics) do
      true -> do_run_with_metrics(func, property)
      false -> func.()
    end
  end

  def metrics() do
    reduce(%{}, fn {name, iterator}, metrics ->
      data =
        @percentiles
        |> Enum.map(&{{:percentile, &1}, value_at_quantile(iterator, &1)})
        |> Enum.into(%{})
        |> Map.merge(%{
          :total_count => total_count(iterator),
          :min => min(iterator),
          :mean => mean(iterator),
          :max => max(iterator)
        })

      Map.put(metrics, name, data)
    end)
  end

  defp do_run_with_metrics(func, property) do
    {time, result} = :timer.tc(func)

    case result do
      {:ok, _} -> record_success(property, time)
      :ok -> record_success(property, time)
      _ -> record_failure(property, time)
    end

    result
  end

  defp record_success(property, time) do
    record!(:metrics, property <> "_success", time)
  end

  defp record_failure(property, time) do
    record!(:metrics, property <> "_failure", time)
  end
end
