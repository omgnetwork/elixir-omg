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

defmodule OMG.Status.Monitor.MemoryMonitor do
  @moduledoc """
  Monitors and raises the :system_memory_too_high alarm when the system memory reaches
  the specified threshold.

  Intentionally raising a different alarm name from :memsup (which uses :system_memory_high_watermark)
  so there is no ambiguity to which module is responsible for which alarm.

  See http://erlang.org/pipermail/erlang-questions/2006-September/023144.html
  """
  use GenServer
  require Logger

  @type t :: %__MODULE__{
          alarm_module: module(),
          interval_ms: pos_integer(),
          pid: pid(),
          raised: boolean(),
          tref: reference() | nil
        }

  defstruct alarm_module: nil,
            interval_ms: nil,
            pid: nil,
            raised: false,
            tref: nil

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init([_ | _] = opts) do
    _ = Logger.info("Starting #{inspect(__MODULE__)}.")
    install_alarm_handler()

    alarm_module = Keyword.fetch!(opts, :alarm_module)
    interval_ms = Keyword.fetch!(opts, :interval_ms)

    state = %__MODULE__{
      alarm_module: alarm_module,
      interval_ms: interval_ms,
      pid: pid
    }

    {:ok, state, {:continue, :first_check}}
  end

  # gen_event init
  def init(_args) do
    {:ok, %{}}
  end

  # We want the first check immediately upon start, but we cannot do it while the monitor
  # is not fully initialized, so we need to trigger it in a :continue instruction.
  def handle_continue(:first_check, state) do
    _ = send(self(), :check)
    {:noreply, state}
  end

  def handle_info(:check, state) do
    exceed_threshold? = system_memory_exceed_threshold?()
    _ = raise_clear(alarm_module, state.raised, exceed_threshold?)

    {:ok, tref} = :timer.send_after(state.interval_ms, :check)
    {:noreply, %{state | tref: tref}}
  end

  def handle_cast(:set_alarm, state) do
    {:noreply, %{state | raised: true}}
  end

  def handle_cast(:clear_alarm, state) do
    {:noreply, %{state | raised: false}}
  end

  #
  # gen_event handlers
  #
  def handle_call(_request, state), do: {:ok, :ok, state}

  def handle_event({:set_alarm, {:system_memory_too_high, %{reporter: __MODULE__}}}, state) do
    _ = Logger.warn("System memory usage is too high. :system_memory_too_high alarm raised.")
    :ok = GenServer.cast(__MODULE__, :set_alarm)
    {:ok, state}
  end

  def handle_event({:clear_alarm, {:system_memory_too_high, %{reporter: __MODULE__}}}, state) do
    _ = Logger.warn("System memory usage went below threshold. :system_memory_too_high alarm cleared.")
    :ok = GenServer.cast(__MODULE__, :clear_alarm)
    {:ok, state}
  end

  def handle_event(event, state) do
    _ = Logger.info("inspect(#{__MODULE__}) got event: #{inspect(event)}. Ignoring.")
    {:ok, state}
  end

  #
  # Memory-checking logic
  #

  defp system_memory_exceed_threshold?() do
    memory = get_memory()
    used = memory.total - (memory.free + memory.buffered + memory.cached)
    used_ratio = used / memory.total

    used_ratio > threshold
  end

  defp get_memory() do
    data = :memsup.get_system_memory_data()

    %{
      total: Keyword.fetch!(data, :total_memory),
      free: Keyword.fetch!(data, :free_memory),
      buffered: Keyword.fetch!(data, :buffered_memory),
      cached: Keyword.fetch!(data, :cached_memory)
    }
  end

  #
  # Alarm management
  #

  # if an alarm is raised, we don't have to raise it again.
  # if an alarm is cleared, we don't need to clear it again
  # we want to avoid pushing events again
  @spec raise_clear(module(), boolean(), boolean()) :: :ok | :duplicate
  defp raise_clear(alarm_module, false, true) do
    alarm_module.set(alarm_module.system_memory_too_high(__MODULE__))
  end

  defp raise_clear(alarm_module, true, false) do
    alarm_module.clear(alarm_module.system_memory_too_high(__MODULE__))
  end

  defp raise_clear(_alarm_module, true, true), do: :ok

  defp raise_clear(_alarm_module, false, false), do: :ok

  defp install_alarm_handler() do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(__MODULE__)
    end
  end
end
