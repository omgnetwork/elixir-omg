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
          children: list(Child.t())
        }
  defstruct alarm_module: nil, children: nil

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init([alarm_module, children_specs]) do
    subscribe_to_alarms()
    Process.flag(:trap_exit, true)

    children = Enum.map(children_specs, &start_child(&1))

    {:ok, %__MODULE__{alarm_module: alarm_module, children: children}}
  end

  # gen_event boot
  def init(_args) do
    {:ok, %{}}
  end

  #
  # gen_event
  #
  def handle_call(_request, state), do: {:ok, :ok, state}

  def handle_event({:clear_alarm, {:ethereum_client_connection, _}}, state) do
    _ = Logger.warn(":ethereum_client_connection alarm was cleared. Beginning to restart processes.")
    :ok = GenServer.cast(__MODULE__, :start_children)
    {:ok, state}
  end

  # flush
  def handle_event(event, state) do
    _ = Logger.info("Monitor got event: #{inspect(event)}. Ignoring.")
    {:ok, state}
  end

  # there's a supervisor below us that did the needed restarts for it's children
  # so we just ignore the exit from the supervisor, if the alarm clears, we restart it
  def handle_info({:EXIT, _from, _reason}, state) do
    {:noreply, state}
  end

  # alarm has cleared, we can now begin restarting children
  def handle_cast(:start_children, state) do
    children = Enum.map(state.children, &start_child(&1))
    {:noreply, %{state | children: children}}
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
