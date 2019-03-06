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

  Children that need Ethereum client connectivity are OMG.API.EthereumEventListener
  OMG.API.BlockQueue.Server and OMG.API.RootChainCoordinator. For these children, we make
  additional checks if they exit. If there's an alarm raised of type :ethereum_client_connection_issue we postpone
  the restart util the alarm is cleared. Other children are restarted immediately.

  """
  use GenServer
  require Logger
  #  alias OMG.API.Alert.Alarm

  @type t :: %__MODULE__{
          children: list(tuple())
        }
  defstruct children: nil

  def start_link(children_specs) do
    GenServer.start_link(__MODULE__, children_specs, name: __MODULE__)
  end

  def init(children_specs) do
    Process.flag(:trap_exit, true)

    children =
      Enum.map(
        children_specs,
        fn spec ->
          start_child(spec)
        end
      )

    {:ok, %__MODULE__{children: children}}
  end

  def handle_info({:EXIT, from, reason}, state) do
    {^from, _module, _child_specs} = find_child_from_dead_pid(from, state)

    # _ = Logger.error(reason)

    # can_start_child?(child_spec)
    {:noreply, state}
  end

  def terminate(_, _), do: :ok

  defp find_child_from_dead_pid(pid, state) do
    List.keyfind(state.children, pid, 0)
  end

  defp start_child({child_module, args} = spec) do
    {:ok, pid} = child_module.start_link(args)
    {pid, child_module, spec}
  end

  defp start_child(%{id: _name, start: {child_module, function, args}} = spec) do
    {:ok, pid} = apply(child_module, function, args)
    {pid, child_module, spec}
  end
end
