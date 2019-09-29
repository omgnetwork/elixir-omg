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

defmodule OMG.ChildChain.Monitor do
  @moduledoc """
  This module is a custom implemented supervisor that monitors all it's chilldren
  and restarts them based on alarms raised. This means that in the period when Geth alarms are raised
  it would wait before it would restart them.
  #TODO - implement a proper supervisor

  When you receive an EXIT, check for an alarm raised that's related to Ethereum client synhronisation or connection
  problems and reacts accordingly.

  If there's an alarm raised of type :ethereum_client_connection we postpone
  the restart util the alarm is cleared. Other children are restarted immediately.

  Implements a GenServer and callbacks of an alarm handler to be able to react to clearead alarms.
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

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init([alarm_module, child_spec]) do
    subscribe_to_alarms()
    Process.flag(:trap_exit, true)

    {:ok, %__MODULE__{alarm_module: alarm_module, child: start_child(child_spec)}}
  end

  # gen_event boot
  def init(_args) do
    {:ok, %{}}
  end

  ###
  ### gen_event
  ###
  def handle_call(_request, state), do: {:ok, :ok, state}

  def handle_event({:clear_alarm, {:ethereum_client_connection, _}}, state) do
    _ = Logger.warn(":ethereum_client_connection alarm was cleared. Beginning to restart processes.")
    :ok = GenServer.cast(__MODULE__, :start_child)
    {:ok, state}
  end

  ### flush
  def handle_event(event, state) do
    _ = Logger.info("Monitor got event: #{inspect(event)}. Ignoring.")
    {:ok, state}
  end

  # There's a supervisor below us that did the needed restarts for it's children
  # so we do not attempt to restart the exit from the supervisor, if the alarm clears, we restart it then.
  # We declare the sytem unhealthy
  def handle_info({:EXIT, _from, _reason}, state) do
    state.alarm_module.set(state.alarm_module.chain_crash(__MODULE__))

    {:noreply, state}
  end

  # alarm has cleared, we can now begin restarting children
  def handle_cast(:start_child, state) do
    child = state.child
    _ = Logger.info("Monitor is restarting children #{inspect(child)} and clearing chain_crash alarm.")

    _ = state.alarm_module.clear(state.alarm_module.chain_crash(__MODULE__))
    {:noreply, %{state | child: start_child(child)}}
  end

  #  We try to find the child specs from the pid that was started.
  #  The child will be updated so we return also the new child list without that child.

  @spec pop_child_from_dead_pid(pid(), list(Child.t())) :: {Child.t(), list(Child.t())} | {nil, list(Child.t())}
  defp pop_child_from_dead_pid(pid, children) do
    item = Enum.find(children, &(&1.pid == pid))

    {item, children -- [item]}
  end

  ### Figure out, if the client is unavailable. If it is, we'll postpone the
  ### restart until the alarm clears. Other processes can be restarted immediately.
  defp restart_or_delay(alarm_module, child) do
    case is_raised?(alarm_module) do
      true ->
        # wait until we get notified that the alarm was cleared
        child

      _ ->
        start_child(child.spec)
    end
  end

  defp start_child({child_module, args} = spec) do
    case child_module.start_link(args) do
      {:ok, pid} ->
        %Child{pid: pid, spec: spec}

      {:error, {:already_started, pid}} ->
        %Child{pid: pid, spec: spec}
    end
  end

  defp start_child(%{id: _name, start: {child_module, function, args}} = spec) do
    case apply(child_module, function, args) do
      {:ok, pid} ->
        %Child{pid: pid, spec: spec}

      {:error, {:already_started, pid}} ->
        %Child{pid: pid, spec: spec}
    end
  end

  defp is_raised?(alarm_module) do
    alarms = alarm_module.all()

    alarms
    |> Enum.find(fn x -> match?(:ethereum_client_connection, elem(x, 0)) end)
    |> is_tuple()
  end

  defp install do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(__MODULE__)
    end
  end
end
