# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.Status.Metric.StatsdMonitorTest do
  use ExUnit.Case, async: true
  alias OMG.Status.Metric.StatsdMonitor

  setup do
    {:ok, apps} = Application.ensure_all_started(:omg_status)
    {:ok, alarm_process} = __MODULE__.Alarm.start(self())

    {:ok, statsd_monitor} =
      StatsdMonitor.start_link(alarm_module: __MODULE__.Alarm, child_module: __MODULE__.StasdWrapper)

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(fn app -> Application.stop(app) end)
      Process.exit(alarm_process, :cleanup)
      Process.exit(statsd_monitor, :cleanup)
      Process.sleep(10)
    end)

    %{
      alarm_process: alarm_process,
      statsd_monitor: statsd_monitor
    }
  end

  test "if exiting process/port sends an exit signal to the parent process", %{alarm_process: alarm_process} do
    :erlang.trace(alarm_process, true, [:receive])
    %{pid: pid} = :sys.get_state(StatsdMonitor)
    true = Process.exit(pid, :testkill)
    assert_receive :got_raise_alarm
  end

  test "if exiting process/port sends an exit signal to the parent process 2", %{
    alarm_process: alarm_process,
    statsd_monitor: _statsd_monitor
  } do
    %{pid: pid} = :sys.get_state(StatsdMonitor)
    :erlang.trace(alarm_process, true, [:receive])
    true = Process.exit(pid, :testkill)
    assert_receive :got_raise_alarm
    assert_receive :got_clear_alarm
  end

  defmodule Alarm do
    use GenServer

    def start(parent) do
      GenServer.start(__MODULE__, [parent], name: __MODULE__)
    end

    def init([parent]) do
      {:ok, %{parent: parent}}
    end

    def statsd_client_connection(reporter),
      do: {:statsd_client_connection, %{node: Node.self(), reporter: reporter}}

    def set({:statsd_client_connection, _details}) do
      GenServer.call(__MODULE__, :got_raise_alarm)
    end

    def clear({:statsd_client_connection, _details}) do
      GenServer.call(__MODULE__, :got_clear_alarm)
    end

    def handle_call(:got_raise_alarm, _, state) do
      {:reply, send(state.parent, :got_raise_alarm), state}
    end

    def handle_call(:got_clear_alarm, _, state) do
      {:reply, send(state.parent, :got_clear_alarm), state}
    end
  end

  defmodule StasdWrapper do
    use GenServer

    def start_link do
      GenServer.start_link(__MODULE__, [], [])
    end

    def init(_) do
      {:ok, %{}}
    end
  end
end
