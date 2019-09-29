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

defmodule OMG.ChildChain.MonitorTest do
  @moduledoc false
  alias __MODULE__.EthereumClientMock

  alias OMG.ChildChain.Monitor
  alias OMG.Status.Alert.Alarm

  use ExUnit.Case, async: true

  @moduletag :integration
  @moduletag :child_chain
  @moduletag timeout: 120_000

  setup_all do
    {:ok, apps} = Application.ensure_all_started(:omg_status)

    on_exit(fn ->
      apps
      |> Enum.reverse()
      |> Enum.each(fn app -> Application.stop(app) end)
    end)

    :ok
  end

  setup do
    Alarm.clear_all()

    on_exit(fn ->
      case Process.whereis(Monitor) do
        nil ->
          :ok

        pid ->
          Process.exit(pid, :kill)
      end

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

  test "when a child is specified as a map spec child gets restarted after alarm is cleared" do
    child = ChildProcess.prepare_child()
    {:ok, monitor_pid} = Monitor.start_link([Alarm, child])
    app_alarm = Alarm.ethereum_client_connection(__MODULE__)
    :ok = :alarm_handler.set_alarm(app_alarm)
    true = Process.unlink(monitor_pid)
    {:links, [child_pid]} = Process.info(monitor_pid, :links)
    :erlang.trace(monitor_pid, true, [:receive])
    true = Process.exit(Process.whereis(ChildProcess), :kill)
    # we prove that we're linked to the child process and that when it gets killed
    # we get the trap exit message
    assert_receive {:trace, ^monitor_pid, :receive, {:EXIT, ^child_pid, :killed}}, 5_000
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

<<<<<<< HEAD
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
  test "if a map spec for child process and tuple spec get restarted after exit" do
    # test with a child defined as a map
    child = EthereumClientMock.prepare_child()
    {:ok, monitor_pid} = Monitor.start_link([Alarm, [child]])
=======
  test "that a child process does not get restarted if an alarm is cleared but it was not down" do
    child = ChildProcess.prepare_child()
    {:ok, monitor_pid} = Monitor.start_link([Alarm, child])
>>>>>>> 94236337... refactor: simplify monitor to one child
    app_alarm = Alarm.ethereum_client_connection(__MODULE__)
    :ok = :alarm_handler.set_alarm(app_alarm)
    :erlang.trace(monitor_pid, true, [:receive])
    {:links, links} = Process.info(monitor_pid, :links)
    just_me = [self()]

    case links do
      _ when links == [] or links == just_me ->
        _ = Process.sleep(10)
        get_child_link(monitor_pid, count - 1)

      _ ->
        links -- just_me
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

    def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

    def init(_), do: {:ok, %{}}

    def terminate(_reason, _) do
      :ok
    end

    def handle_call({:terminate, reason}, _, state), do: {:stop, reason, state}

    def handle_call(:terminate_ethereum_client_connection, _, state),
      do: Process.exit(self(), {{:ethereum_client_connection, :normal}, state})
  end
end
