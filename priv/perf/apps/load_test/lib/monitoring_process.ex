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

defmodule LoadTest.MonitoringProcess do
  use GenServer

  require Logger

  def start_link(params) do
    GenServer.start_link(__MODULE__, params)
  end

  def record_metrics(pid, params) do
    GenServer.cast(pid, {:record_metrics, params})
  end

  @impl true
  def init({test, params}) do
    run_config = Map.put(params[:run_config], :monitoring_process, self())
    new_params = %{params | run_config: run_config}

    task =
      Task.async(fn ->
        Chaperon.run_load_test(test, config: new_params)
      end)

    {:ok, %{task: task, transactions_count: 0, errors_count: 0, state: :running}}
  end

  @impl true
  def handle_cast({:record_metrics, data}, state) do
    transactions_count = state.transactions_count + 1

    errors_count =
      case data[:status] do
        :ok -> state.errors_count
        _ -> state.errors_count + 1
      end

    {:noreply, %{state | errors_count: errors_count, transactions_count: transactions_count}}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %{task: %{pid: pid}} = state) do
    _ = Logger.error("Test task failed #{inspect(reason)}")

    {:noreply, Map.put(state, :state, :failed)}
  end

  @impl true
  def handle_info({:EXIT, pid, :normal}, %{task: %{pid: pid}} = state) do
    _ = Logger.info("Test task finished")

    {:noreply, Map.put(state, :state, :finished)}
  end
end
