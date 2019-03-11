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

defmodule OMG.API.MonitorTest do
  @moduledoc false
  alias OMG.API.Alert.Alarm
  alias OMG.API.Alert.AlarmHandler
  alias OMG.API.Monitor
  use ExUnit.Case, async: true

  setup_all do
    :ok = AlarmHandler.install()
  end

  setup do
    Alarm.clear_all()

    on_exit(fn ->
      Process.exit(Process.whereis(Monitor), :kill)

      case Process.whereis(__MODULE__.Mock) do
        nil ->
          :ok

        pid ->
          Process.exit(pid, :kill)
      end

      :ok
    end)

    :ok
  end

  test "if a tuple spec child gets started" do
    {:ok, monitor_pid} = Monitor.start_link([{__MODULE__.Mock, []}])
    Process.unlink(monitor_pid)
    {:links, links} = Process.info(monitor_pid, :links)

    names =
      Enum.map(links, fn x ->
        {:registered_name, registered_name} = Process.info(x, :registered_name)
        registered_name
      end)

    assert Enum.member?(names, __MODULE__.Mock)
  end

  test "if a map spec child gets started" do
    {:ok, monitor_pid} = Monitor.start_link([__MODULE__.Mock.prepare_child()])
    Process.unlink(monitor_pid)
    {:links, links} = Process.info(monitor_pid, :links)

    names =
      Enum.map(links, fn x ->
        {:registered_name, registered_name} = Process.info(x, :registered_name)
        registered_name
      end)

    assert Enum.member?(names, __MODULE__.Mock)
  end

  test "if a map spec child gets restarted after exit" do
    child = __MODULE__.Mock.prepare_child()
    {:ok, monitor_pid} = Monitor.start_link([child])
    handle_killing_and_monitoring(monitor_pid)
  end

  test "if a tuple spec child gets restarted after exit" do
    child = {__MODULE__.Mock, []}
    {:ok, monitor_pid} = Monitor.start_link([child])
    handle_killing_and_monitoring(monitor_pid)
  end

  test "if a child gets a interval set after termination" do
    child = {__MODULE__.Mock, []}
    {:ok, monitor_pid} = Monitor.start_link([child])
    Process.unlink(monitor_pid)
    Alarm.raise({:ethereum_client_connection, :erlang.node(), __MODULE__})
    spawn(fn -> __MODULE__.Mock.terminate(:ethereum_client_connection) end)
    assert pull_state_and_find_timer(monitor_pid, 1000)
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

    assert Enum.member?(names, __MODULE__.Mock)
    # process is started and is monitored, lets log the pid
    old_pid = Process.whereis(__MODULE__.Mock)
    Process.unlink(old_pid)
    # exit the pid by sending a shutdown command
    spawn(fn -> __MODULE__.Mock.terminate(:kill) end)

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

    case {Enum.member?(names, __MODULE__.Mock), old_pid == Process.whereis(__MODULE__.Mock)} do
      {true, false} ->
        true

      _ ->
        Process.sleep(10)
        pull_links_and_find_process(monitor_pid, old_pid, index - 1)
    end
  end

  defp pull_state_and_find_timer(_, 0), do: false

  defp pull_state_and_find_timer(monitor_pid, index) do
    case hd(:sys.get_state(monitor_pid)) do
      %{tref: {:interval, tref}} ->
        is_reference(tref)

      _ ->
        Process.sleep(10)
        pull_state_and_find_timer(monitor_pid, index - 1)
    end
  end

  defmodule Mock do
    @moduledoc """
    Mocking the ETH module integration point.
    """
    use GenServer
    @spec prepare_child() :: %{id: atom(), start: tuple()}
    def prepare_child do
      %{id: __MODULE__, start: {__MODULE__, :start_link, [[]]}}
    end

    def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)
    def terminate(:ethereum_client_connection), do: GenServer.call(__MODULE__, :terminate_ethereum_client_connection)
    def terminate(reason), do: GenServer.call(__MODULE__, {:terminate, reason})

    def init(_), do: {:ok, %{}}
    def handle_call({:terminate, reason}, _, state), do: {:stop, reason, state}

    def handle_call(:terminate_ethereum_client_connection, _, state),
      do: Process.exit(self(), {{:ethereum_client_connection, :normal}, state})

    # processes that are dependent on the client connectivity return an extra indicator :ethereum_client_connection
  end
end
