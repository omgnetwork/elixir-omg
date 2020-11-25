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

defmodule OMG.Status.Monitor.StatsdMonitor do
  @moduledoc """
  This module is a custom implemented supervisor that monitors all it's chilldren.
  """
  use GenServer

  require Logger

  @type t :: %__MODULE__{
          alarm_module: module(),
          child_module: module(),
          interval: pos_integer(),
          pid: pid(),
          raised: boolean(),
          tref: reference() | nil
        }

  defstruct alarm_module: nil,
            child_module: nil,
            interval: Application.get_env(:omg_status, :statsd_reconnect_backoff_ms),
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
    child_module = Keyword.fetch!(opts, :child_module)
    false = Process.flag(:trap_exit, true)
    {:ok, pid} = apply(child_module, :start_link, [])

    state = %__MODULE__{
      alarm_module: alarm_module,
      child_module: child_module,
      pid: pid
    }

    _ = raise_clear(alarm_module, state.raised, Process.alive?(pid))
    {:ok, state}
  end

  # gen_event init
  def init(_args) do
    {:ok, %{}}
  end

  def handle_info({:EXIT, _, reason}, state) do
    _ = Logger.error("Monitored datadog connection process from statix died of reason #{inspect(reason)} ")
    _ = state.alarm_module.set(state.alarm_module.statsd_client_connection(__MODULE__))
    _ = :timer.cancel(state.tref)
    {:ok, tref} = :timer.send_after(state.interval, :connect)
    {:noreply, %{state | raised: true, tref: tref}}
  end

  def handle_info(:connect, state) do
    {:ok, pid} = apply(state.child_module, :start_link, [])
    alive = Process.alive?(pid)
    _ = raise_clear(state.alarm_module, state.raised, alive)
    {:noreply, %{state | pid: pid}}
  end

  def handle_cast(:clear_alarm, state) do
    {:noreply, %{state | raised: false}}
  end

  def handle_cast(:set_alarm, state) do
    {:noreply, %{state | raised: true}}
  end

  def terminate(_, _), do: :ok

  #
  # gen_event
  #
  def handle_call(_request, state), do: {:ok, :ok, state}

  def handle_event({:clear_alarm, {:statsd_client_connection, %{reporter: __MODULE__}}}, state) do
    _ = Logger.warn("Established connection to the client. :statsd_client_connection alarm clearead.")
    :ok = GenServer.cast(__MODULE__, :clear_alarm)
    {:ok, state}
  end

  def handle_event({:set_alarm, {:statsd_client_connection, %{reporter: __MODULE__}}}, state) do
    _ = Logger.warn("Connection dropped raising :statsd_client_connection alarm.")
    :ok = GenServer.cast(__MODULE__, :set_alarm)
    {:ok, state}
  end

  # flush
  def handle_event(event, state) do
    _ = Logger.info("#{__MODULE__} got event: #{inspect(event)}. Ignoring.")
    {:ok, state}
  end

  # if an alarm is raised, we don't have to raise it again.
  # if an alarm is cleared, we don't need to clear it again
  # we want to avoid pushing events again
  @spec raise_clear(module(), boolean(), boolean()) :: :ok | :duplicate
  defp raise_clear(_alarm_module, true, false), do: :ok

  defp raise_clear(alarm_module, false, false),
    do: alarm_module.set(alarm_module.statsd_client_connection(__MODULE__))

  defp raise_clear(alarm_module, true, _),
    do: alarm_module.clear(alarm_module.statsd_client_connection(__MODULE__))

  defp raise_clear(_alarm_module, false, _), do: :ok

  defp install_alarm_handler() do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(__MODULE__)
    end
  end
end
