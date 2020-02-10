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

defmodule OMG.Watcher.Monitor do
  @moduledoc """
  This module restarts it's children if the Ethereum client
  connectivity is dropped.
  It subscribes to alarms and when an alarm is cleared it restarts it
  children if they're dead.
  """
  defmodule Child do
    @moduledoc false
    @type t :: %__MODULE__{
            pid: pid(),
            spec: {module(), term()} | map()
          }
    defstruct pid: nil, spec: nil
  end

  use GenServer

  require Logger

  @type t :: %__MODULE__{
          alarm_module: module(),
          child: Child.t()
        }
  defstruct alarm_module: nil, child: nil

  def health_checkin() do
    GenServer.cast(__MODULE__, :health_checkin)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init([alarm_module, child_spec]) do
    subscribe_to_alarms()
    Process.flag(:trap_exit, true)
    # we raise the alarms first, because we get a health checkin when all
    # sub processes of the supervisor are ready to go
    _ = alarm_module.set(alarm_module.main_supervisor_halted(__MODULE__))
    {:ok, %__MODULE__{alarm_module: alarm_module, child: start_child(child_spec)}}
  end

  # gen_event boot
  def init(_args) do
    {:ok, %{}}
  end

  #
  # gen_event
  #
  def handle_call(_request, state), do: {:ok, :ok, state}

  def handle_event({:clear_alarm, {:ethereum_connection_error, _}}, state) do
    _ = Logger.warn(":ethereum_connection_error alarm was cleared. Beginning to restart processes.")
    :ok = GenServer.cast(__MODULE__, :start_child)
    {:ok, state}
  end

  # flush
  def handle_event(event, state) do
    _ = Logger.info("Monitor got event: #{inspect(event)}. Ignoring.")
    {:ok, state}
  end

  # There's a supervisor below us that did the needed restarts for it's children
  # so we do not attempt to restart the exit from the supervisor, if the alarm clears, we restart it then.
  # We declare the sytem unhealthy
  def handle_info({:EXIT, _from, reason}, state) do
    _ = Logger.error("Watcher supervisor crashed. Raising alarm. Reason #{inspect(reason)}")
    state.alarm_module.set(state.alarm_module.main_supervisor_halted(__MODULE__))

    {:noreply, state}
  end

  # alarm has cleared, we can now begin restarting supervisor child
  def handle_cast(:health_checkin, state) do
    _ = Logger.info("Got a health checkin... clearing alarm main_supervisor_halted.")
    _ = state.alarm_module.clear(state.alarm_module.main_supervisor_halted(__MODULE__))
    {:noreply, state}
  end

  # alarm has cleared, we can now begin restarting supervisor child
  def handle_cast(:start_child, state) do
    child = state.child
    _ = Logger.info("Monitor is restarting child #{inspect(child)}.")

    {:noreply, %{state | child: start_child(child)}}
  end

  defp start_child(%{id: _name, start: {child_module, function, args}} = spec) do
    {:ok, pid} = apply(child_module, function, args)
    %Child{pid: pid, spec: spec}
  end

  defp start_child(%Child{pid: pid, spec: spec} = child) do
    case Process.alive?(pid) do
      true ->
        child

      false ->
        %{id: _name, start: {child_module, function, args}} = spec
        {:ok, pid} = apply(child_module, function, args)
        %Child{pid: pid, spec: spec}
    end
  end

  defp subscribe_to_alarms() do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(__MODULE__)
    end
  end
end
