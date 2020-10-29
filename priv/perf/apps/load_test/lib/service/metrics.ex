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
  def run_with_metrics(func, property) do
    case Application.get_env(:load_test, :record_metrics) do
      true -> do_run_with_metrics(func, property)
      false -> func.()
    end
  end

  def metrics() do
    GenServer.call(__MODULE__, :state)
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
    GenServer.cast(__MODULE__, {:success, property, time})
  end

  defp record_failure(property, time) do
    GenServer.cast(__MODULE__, {:failure, property, time})
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:success, property, time}, state) do
    default_value = %{
      total_requests: 1,
      successful_requests: 1,
      failed_requests: 0,
      average_successful_time: time,
      average_failed_time: 0
    }

    new_state =
      Map.update(state, property, default_value, fn existing_value ->
        new_successful_requests = existing_value.successful_requests + 1

        new_average_successful_time =
          (existing_value.successful_requests * existing_value.average_successful_time + time) / new_successful_requests

        %{
          existing_value
          | average_successful_time: new_average_successful_time,
            total_requests: existing_value.total_requests + 1,
            successful_requests: new_successful_requests
        }
      end)

    {:noreply, new_state}
  end

  def handle_cast({:failure, property, time}, state) do
    default_value = %{
      total_requests: 1,
      successful_requests: 0,
      failed_requests: 1,
      average_successful_time: 0,
      average_failed_time: time
    }

    new_state =
      Map.update(state, property, default_value, fn existing_value ->
        new_failed_requests = existing_value.failed_requests + 1

        new_average_failed_time =
          (existing_value.failed_requests * existing_value.average_failed_time + time) / new_failed_requests

        %{
          existing_value
          | average_failed_time: new_average_failed_time,
            total_requests: existing_value.total_requests + 1,
            failed_requests: new_failed_requests
        }
      end)

    {:noreply, new_state}
  end
end
