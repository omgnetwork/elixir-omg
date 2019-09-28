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
  alias __MODULE__.ChildProcess
  alias OMG.ChildChain.Monitor
  alias OMG.Status.Alert.Alarm

  use ExUnit.Case, async: true

  @moduletag :integration
  @moduletag :child_chain

  setup_all do
    {:ok, apps} = Application.ensure_all_started(:omg_status)

    on_exit(fn ->
      apps
      |> Enum.reverse()
      |> Enum.each(fn app -> Application.stop(app) end)

      case Process.whereis(Monitor) do
        nil ->
          :ok

        pid ->
          Process.exit(pid, :kill)
      end
    end)

    :ok
  end

  test "when a child is specified as a map spec child gets restarted after alarm is cleared" do
    child = ChildProcess.prepare_child()
    {:ok, monitor_pid} = Monitor.start_link([Alarm, [child]])
    app_alarm = {:ethereum_client_connection, %{node: Node.self(), reporter: __MODULE__}}
    :ok = :alarm_handler.set_alarm(app_alarm)
    true = Process.unlink(monitor_pid)
    {:links, [child_pid]} = Process.info(monitor_pid, :links)
    true = Process.exit(Process.whereis(ChildProcess), :kill)
    # we prove that we're linked to the child process and that when it gets killed
    # we get the trap exit message
    :erlang.trace(monitor_pid, true, [:receive])
    assert_receive {:trace, ^monitor_pid, :receive, {:EXIT, ^child_pid, :killed}}, 5_000
    {:links, links} = Process.info(monitor_pid, :links)
    assert Enum.empty?(links) == true
    # now we can clear the alarm and let the monitor restart the child process
    :ok = :alarm_handler.clear_alarm(app_alarm)
    assert_receive {:trace, ^monitor_pid, :receive, {:"$gen_cast", :start_children}}
    {:links, links} = Process.info(monitor_pid, :links)
    assert Enum.empty?(links) == false
    # cleanup
    true = Process.link(monitor_pid)
  end

  defmodule ChildProcess do
    @moduledoc """
    Mocking a child process to Monitor
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
  end
end
