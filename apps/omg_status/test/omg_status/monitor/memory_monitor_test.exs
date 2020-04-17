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

defmodule OMG.Status.Monitor.MemoryMonitorTest do
  use ExUnit.Case, async: true
  alias OMG.Status.Monitor.MemoryMonitor

  setup do
    {:ok, apps} = Application.ensure_all_started(:omg_status)
    {:ok, _} = __MODULE__.Alarm.start_link(self())
    {:ok, _} = __MODULE__.Memsup.start_link()

    {:ok, monitor_pid} =
      MemoryMonitor.start_link(
        alarm_module: __MODULE__.Alarm,
        memsup_module: __MODULE__.Memsup,
        interval_ms: 10,
        threshold: 0.8
      )

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    end)

    {:ok, %{monitor_pid: monitor_pid}}
  end

  test "raises an alarm if used memory is above the threshold" do
    set_memsup([total_memory: 1000, free_memory: 100, buffered_memory: 0, cached_memory: 0])
    assert_receive :got_raise_alarm
  end

  test "clears the alarm if used memory is below threshold", context do
    :sys.replace_state(context.monitor_pid, fn state -> %{state | raised: true} end)
    set_memsup([total_memory: 1000, free_memory: 201, buffered_memory: 0, cached_memory: 0])
    assert_receive :got_clear_alarm
  end

  test "raises an alarm if combined used memory is above the threshold" do
    set_memsup([total_memory: 1000, free_memory: 60, buffered_memory: 60, cached_memory: 60])
    assert_receive :got_raise_alarm
  end

  test "clears the alarm if combined used memory is below threshold", context do
    :sys.replace_state(context.monitor_pid, fn state -> %{state | raised: true} end)
    set_memsup([total_memory: 1000, free_memory: 70, buffered_memory: 70, cached_memory: 70])
    assert_receive :got_clear_alarm
  end

  defp set_memsup(memory_data) do
    :sys.replace_state(__MODULE__.Memsup, fn _ -> memory_data end)
  end

  defmodule Alarm do
    use GenServer

    def start_link(parent) do
      GenServer.start_link(__MODULE__, [parent], name: __MODULE__)
    end

    def init([parent]) do
      {:ok, %{parent: parent}}
    end

    def system_memory_too_high(reporter) do
      {:system_memory_too_high, %{node: Node.self(), reporter: reporter}}
    end

    def set({:system_memory_too_high, _}) do
      GenServer.call(__MODULE__, :got_raise_alarm)
    end

    def clear({:system_memory_too_high, _}) do
      GenServer.call(__MODULE__, :got_clear_alarm)
    end

    def handle_call(:got_raise_alarm, _, state) do
      {:reply, send(state.parent, :got_raise_alarm), state}
    end

    def handle_call(:got_clear_alarm, _, state) do
      {:reply, send(state.parent, :got_clear_alarm), state}
    end
  end

  defmodule Memsup do
    use GenServer

    def start_link() do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    def init(_) do
      memory_data = [
        total_memory: 1000,
        free_memory: 1000,
        buffered_memory: 0,
        cached_memory: 0
      ]

      {:ok, memory_data}
    end

    def get_system_memory_data() do
      GenServer.call(__MODULE__, :get_system_memory_data)
    end

    def handle_call(:get_system_memory_data, _, state) do
      {:reply, state, state}
    end
  end
end
