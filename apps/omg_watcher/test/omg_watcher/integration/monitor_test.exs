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

defmodule OMG.Watcher.MonitorTest do
  @moduledoc false
  alias __MODULE__.EthereumClientMock

  alias OMG.Status.Alert.Alarm
  alias OMG.Watcher.Monitor

  use ExUnit.Case, async: true

  @moduletag :integration
  @moduletag :watcher
  @moduletag timeout: 120_000

  setup_all do
    _ = Application.ensure_all_started(:omg_status)
    :ok
  end

  setup do
    Alarm.clear_all()

    on_exit(fn ->
      Process.exit(Process.whereis(Monitor), :kill)

      case Process.whereis(EthereumClientMock) do
        nil ->
          :ok

        pid ->
          Process.exit(pid, :kill)
      end

      :ok
    end)

    :ok
  end

  @tag :capture_log
  test "if a tuple spec child gets restarted after alarm is raised" do
    {:ok, monitor_pid} = Monitor.start_link([Alarm, [{EthereumClientMock, []}]])
    _ = Process.unlink(monitor_pid)
    {:links, links} = Process.info(monitor_pid, :links)

    names =
      Enum.map(links, fn x ->
        {:registered_name, registered_name} = Process.info(x, :registered_name)
        registered_name
      end)

    assert Enum.member?(names, EthereumClientMock)
  end

  @tag :capture_log
  test "if a tuple spec child gets started" do
    parent = self()
    {:ok, _} = :dbg.tracer(:process, {fn msg, _ -> send(parent, msg) end, []})
    {:ok, _} = :dbg.tpl(Monitor, :is_raised?, [{:_, [], [{:return_trace}]}])
    {:ok, _} = :dbg.p(:all, [:call])
    {:ok, monitor_pid} = Monitor.start_link([Alarm, [{EthereumClientMock, []}]])
    _ = Process.unlink(monitor_pid)
    {:links, links} = Process.info(monitor_pid, :links)

    names =
      Enum.map(links, fn x ->
        {:registered_name, registered_name} = Process.info(x, :registered_name)
        registered_name
      end)

    assert Enum.member?(names, EthereumClientMock)
    # everything is nice and dandy, now we raise an alarm and exit the child process that the monitor
    # is monitoring
    app_alarm = {:ethereum_client_connection, %{node: Node.self(), reporter: Reporter}}
    :ok = :alarm_handler.set_alarm(app_alarm)
    true = Process.exit(Process.whereis(EthereumClientMock), :kill)
    :dbg.stop_clear()
    # we're testing that the timer's work and that private functions for
    # checking for raised alarms are properly detecting it
    receive do
      {:trace, ^monitor_pid, :call, {Monitor, :is_raised?, [_]}} ->
        receive do
          {:trace, ^monitor_pid, :return_from, {Monitor, :is_raised?, 1}, data} ->
            assert data == true
        end
    end
  end

  test "if a map spec child gets started" do
    {:ok, monitor_pid} = Monitor.start_link([Alarm, [EthereumClientMock.prepare_child()]])
    Process.unlink(monitor_pid)
    {:links, links} = Process.info(monitor_pid, :links)

    names =
      Enum.map(links, fn x ->
        {:registered_name, registered_name} = Process.info(x, :registered_name)
        registered_name
      end)

    assert Enum.member?(names, EthereumClientMock)
  end

  @tag :capture_log
  test "if a map spec child gets restarted after exit" do
    child = EthereumClientMock.prepare_child()
    {:ok, monitor_pid} = Monitor.start_link([Alarm, [child]])
    handle_killing_and_monitoring(monitor_pid)
  end

  @tag :capture_log
  test "if a tuple spec child gets restarted after exit" do
    child = {EthereumClientMock, []}
    {:ok, monitor_pid} = Monitor.start_link([Alarm, [child]])
    handle_killing_and_monitoring(monitor_pid)
  end

  defp handle_killing_and_monitoring(monitor_pid) do
    # 1. we start the child and log the pid
    # 2. exit the pid
    # 3. wait for the child with the name registered name gets restarted by the monitor
    # 4. and check that pids don't match
    Process.unlink(monitor_pid)
    {:links, links} = Process.info(monitor_pid, :links)

    names =
      Enum.map(links, fn x ->
        {:registered_name, registered_name} = Process.info(x, :registered_name)
        registered_name
      end)

    assert Enum.member?(names, EthereumClientMock)
    # process is started and is monitored, lets log the pid
    old_pid = Process.whereis(EthereumClientMock)
    Process.unlink(old_pid)
    # exit the pid by sending a shutdown command
    spawn(fn -> EthereumClientMock.terminate(:kill) end)

    assert pull_links_and_find_process(monitor_pid, old_pid, 10_000)
  end

  defp pull_links_and_find_process(_, _, 0), do: false

  defp pull_links_and_find_process(monitor_pid, old_pid, index) do
    {:links, links} = Process.info(monitor_pid, :links)

    names =
      Enum.map(links, fn x ->
        {:registered_name, registered_name} = Process.info(x, :registered_name)
        registered_name
      end)

    case {Enum.member?(names, EthereumClientMock), old_pid == Process.whereis(EthereumClientMock)} do
      {true, false} ->
        true

      _ ->
        Process.sleep(10)
        pull_links_and_find_process(monitor_pid, old_pid, index - 1)
    end
  end

  defmodule EthereumClientMock do
    @moduledoc """
    Mocking the ETH module integration point.
    """
    use GenServer
    @spec prepare_child() :: %{id: atom(), start: tuple()}
    def prepare_child do
      %{id: __MODULE__, start: {__MODULE__, :start_link, [[]]}}
    end

    def start_link([:no_name]), do: GenServer.start_link(__MODULE__, [:no_name])
    def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

    def init([:no_name]) do
      Process.sleep(3_000)
      {:ok, %{}}
    end

    def init(_), do: {:ok, %{}}

    def terminate(:ethereum_client_connection), do: GenServer.call(__MODULE__, :terminate_ethereum_client_connection)
    def terminate(reason), do: GenServer.call(__MODULE__, {:terminate, reason})

    def handle_call({:terminate, reason}, _, state), do: {:stop, reason, state}

    def handle_call(:terminate_ethereum_client_connection, _, state),
      do: Process.exit(self(), {{:ethereum_client_connection, :normal}, state})
  end
end
