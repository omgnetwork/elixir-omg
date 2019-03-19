# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.API.Monitor do
  @moduledoc """
  This module is a custom implemented supervisor that monitors all it's chilldren
  and restarts them based on alarms raised. This means that in the period when Geth alarms are raised
  it would wait before it would restart them.

  When you receive an EXIT, check for an alarm raised that's related to Ethereum client synhronisation or connection
  problems and react accordingly.

  Children that need Ethereum client connectivity are OMG.EthereumEventListener
  OMG.API.BlockQueue.Server and OMG.RootChainCoordinator. For these children, we make
  additional checks if they exit. If there's an alarm raised of type :ethereum_client_connection we postpone
  the restart util the alarm is cleared. Other children are restarted immediately.

  """
  use GenServer
  require Logger
  alias OMG.API.Alert.Alarm
  # needs to be less then checks from RootChainCoordinator
  @default_interval 300
  @type t :: %__MODULE__{
          pid: pid(),
          spec: {module(), term()} | map(),
          tref: :timer.tref() | nil
        }
  defstruct pid: nil, spec: nil, tref: nil

  def start_link(children_specs) do
    GenServer.start_link(__MODULE__, children_specs, name: __MODULE__)
  end

  def init(children_specs) do
    Process.flag(:trap_exit, true)

    children = Enum.map(children_specs, &start_child(&1))

    {:ok, children}
  end

  def handle_info({:delayed_restart, child}, state) do
    # child still holds the old pid

    from = child.pid

    with false <- is_raised?(),
         {%__MODULE__{pid: ^from, tref: tref} = child, other_children} <- find_child_from_dead_pid(from, state) do
      {:ok, :cancel} = :timer.cancel(tref)

      new_child = start_child(child.spec)

      {:noreply, [new_child | other_children]}
    else
      _ ->
        # alarm is still raised, or the child was already cleared from state in a previous timer

        {:noreply, state}
    end
  end

  # we got an exit signal from a linked child, we have to act as a supervisor now and decide what to do
  # we try to find the child via his old pid that we kept in the state, retrieve his exit reason and specification for
  # starting the child
  def handle_info({:EXIT, from, _reason}, state) do
    {%__MODULE__{pid: ^from} = child, other_children} = find_child_from_dead_pid(from, state)

    new_child = restart_or_delay(child)

    {:noreply, [new_child | other_children]}
  end

  #  We try to find the child specs from the pid that was started.
  #  The child will be updated so we return also the new child list without that child.

  @spec find_child_from_dead_pid(pid(), list(t)) :: {t, list(t)} | {nil, list(t)}
  defp find_child_from_dead_pid(pid, state) do
    item = Enum.find(state, &(&1.pid == pid))

    {item, state -- [item]}
  end

  ### Figure out, if the client is unavailable. If it is, we'll postpone the
  ### restart until the alarm clears. Other processes can be restarted immediately.
  defp restart_or_delay(child) do
    case is_raised?() do
      true ->
        {:ok, tref} = :timer.send_interval(@default_interval, {:delayed_restart, child})

        %__MODULE__{child | tref: tref}

      _ ->
        start_child(child.spec)
    end
  end

  defp start_child({child_module, args} = spec) do
    {:ok, pid} = child_module.start_link(args)
    %__MODULE__{pid: pid, spec: spec}
  end

  defp start_child(%{id: _name, start: {child_module, function, args}} = spec) do
    {:ok, pid} = apply(child_module, function, args)
    %__MODULE__{pid: pid, spec: spec}
  end

  defp is_raised?() do
    alarms = Alarm.all()

    alarms
    |> Enum.find(fn x -> match?(%{id: :ethereum_client_connection}, x) end)
    |> is_map()
  end
end
