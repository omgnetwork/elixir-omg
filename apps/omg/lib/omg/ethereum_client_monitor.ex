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

defmodule OMG.EthereumClientMonitor do
  @moduledoc """
  This module periodically checks Geth (every second or less) and raises an alarm
  when it can't reach the client and clears the alarm when the client connection is established again.

  The module implements a genserver that repeatedly checks the health of the ethereum client and it also implements
  alarm handler callbacks. When the genserver raises an alarm, we get a callback and get notified - and we update our state (raised = true).
  """
  use GenServer
  require Logger
  alias OMG.Eth

  @default_interval Application.get_env(:omg, :client_monitor_interval_ms)
  @type t :: %__MODULE__{
          interval: pos_integer(),
          tref: reference() | nil,
          alarm_module: module(),
          raised: boolean()
        }
  defstruct interval: @default_interval, tref: nil, alarm_module: nil, raised: true

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init([alarm_module]) do
    _ = Logger.info("Starting Ethereum client monitor.")
    install()
    state = %__MODULE__{alarm_module: alarm_module}
    _ = alarm_module.set({:ethereum_client_connection, Node.self(), __MODULE__})
    _ = raise_clear(alarm_module, state.raised, check())
    {:ok, tref} = :timer.send_after(state.interval, :health_check)
    {:ok, %{state | tref: tref}}
  end

  # gen_event
  def init(_args) do
    {:ok, %{}}
  end

  def handle_info(:health_check, state) do
    _ = raise_clear(state.alarm_module, state.raised, check())
    {:ok, tref} = :timer.send_after(state.interval, :health_check)
    {:noreply, %{state | tref: tref}}
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

  def handle_event({:clear_alarm, {:ethereum_client_connection, %{reporter: __MODULE__}}}, state) do
    _ = Logger.warn("Health check established connection to the client. :ethereum_client_connection alarm clearead.")
    :ok = GenServer.cast(__MODULE__, :clear_alarm)
    {:ok, state}
  end

  def handle_event({:set_alarm, {:ethereum_client_connection, %{reporter: __MODULE__}}}, state) do
    _ = Logger.warn("Health check raised :ethereum_client_connection alarm.")
    :ok = GenServer.cast(__MODULE__, :set_alarm)
    {:ok, state}
  end

  # flush
  def handle_event(event, state) do
    _ = Logger.info("Eth client monitor got event: #{inspect(event)}. Ignoring.")
    {:ok, state}
  end

  @spec check :: non_neg_integer() | :error
  defp check do
    {:ok, rootchain_height} = eth().get_ethereum_height()
    rootchain_height
  rescue
    _ -> :error
  end

  # if an alarm is raised, we don't have to raise it again.
  # if an alarm is cleared, we don't need to clear it again
  # we want to avoid pushing events again
  @spec raise_clear(module(), boolean(), :error | non_neg_integer()) :: :ok | :duplicate
  defp raise_clear(_alarm_module, true, :error), do: :ok

  defp raise_clear(alarm_module, false, :error),
    do: alarm_module.set({:ethereum_client_connection, Node.self(), __MODULE__})

  defp raise_clear(alarm_module, true, _),
    do: alarm_module.clear({:ethereum_client_connection, Node.self(), __MODULE__})

  defp raise_clear(_alarm_module, false, _), do: :ok

  defp eth, do: Application.get_env(:omg_child_chain, :eth_integration_module, Eth)

  defp install do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(__MODULE__)
    end
  end
end
