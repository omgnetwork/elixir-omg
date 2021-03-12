# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Watcher.MonitorTest do
  @moduledoc false

  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias __MODULE__.ChildProcess
  alias OMG.Status.Alert.Alarm
  alias OMG.Watcher.Monitor

  use ExUnit.Case, async: true

  setup_all do
    {:ok, apps} = Application.ensure_all_started(:omg_status)

    on_exit(fn ->
      apps
      |> Enum.reverse()
      |> Enum.each(&Application.stop/1)
    end)

    :ok
  end

  setup do
    on_exit(fn ->
      case Process.whereis(Monitor) do
        nil ->
          :ok

        pid ->
          Process.exit(pid, :kill)
      end
    end)

    :ok
  end

  test "that a child process gets restarted after alarm is cleared" do
    child = ChildProcess.prepare_child()
    {:ok, monitor_pid} = start_and_attach_a_child([Alarm, child])
    app_alarm = Alarm.ethereum_connection_error(__MODULE__)

    # the monitor is now started, we raise an alarm and kill it's child
    :ok = :alarm_handler.set_alarm(app_alarm)
    _ = Process.unlink(monitor_pid)
    {:links, [child_pid]} = Process.info(monitor_pid, :links)
    :erlang.trace(monitor_pid, true, [:receive])
    # the child is now killed
    capture_log(fn ->
      true = Process.exit(Process.whereis(ChildProcess), :kill)
    end)

    # we prove that we're linked to the child process and that when it gets killed
    # we get the trap exit message
    assert_receive {:trace, ^monitor_pid, :receive, {:EXIT, ^child_pid, :killed}}, 5_000
    {:links, links} = Process.info(monitor_pid, :links)
    assert Enum.empty?(links) == true
    # now we can clear the alarm and let the monitor restart the child process
    # and trace that the child process gets started
    capture_log(fn ->
      :ok = :alarm_handler.clear_alarm(app_alarm)
    end)

    assert_receive {:trace, ^monitor_pid, :receive, {:"$gen_cast", :start_child}}
    :erlang.trace(monitor_pid, false, [:receive])
    # we now assert that our child was re-attached to the monitor
    Process.sleep(100)
    {:links, children} = Process.info(monitor_pid, :links)
    assert Enum.count(children) == 1
  end

  test "that a child process does not get restarted if an alarm is cleared but it was not down" do
    child = ChildProcess.prepare_child()
    {:ok, monitor_pid} = start_and_attach_a_child([Alarm, child])
    app_alarm = Alarm.ethereum_connection_error(__MODULE__)
    :ok = :alarm_handler.set_alarm(app_alarm)
    :erlang.trace(monitor_pid, true, [:receive])
    {:links, links} = Process.info(monitor_pid, :links)
    # now we clear the alarm and let the monitor restart the child processes
    # in our case the child is alive so init should NOT be called
    capture_log(fn ->
      :ok = :alarm_handler.clear_alarm(app_alarm)
    end)

    assert_receive {:trace, ^monitor_pid, :receive, {:"$gen_cast", :start_child}}, 1500
    # at this point we're just verifying that we didn't restart or start
    # another child
    assert Process.info(monitor_pid, :links) == {:links, links}
  end

  defp start_and_attach_a_child(opts) do
    case Monitor.start_link(opts) do
      {:ok, monitor_pid} ->
        {:ok, monitor_pid}

      {:error, {{:badmatch, {:error, {:already_started, _}}}, _}} ->
        Process.sleep(500)
        start_and_attach_a_child(opts)
    end
  end

  defmodule ChildProcess do
    @moduledoc """
    Mocking a child process to Monitor
    """
    use GenServer

    @spec prepare_child() :: %{id: atom(), start: tuple()}
    def prepare_child() do
      %{id: __MODULE__, start: {__MODULE__, :start_link, [[]]}}
    end

    def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

    def init(_), do: {:ok, %{}}

    def terminate(_reason, _) do
      :ok
    end
  end
end
