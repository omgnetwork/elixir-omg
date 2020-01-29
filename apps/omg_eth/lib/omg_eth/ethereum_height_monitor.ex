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

defmodule OMG.Eth.EthereumHeightMonitor do
  @moduledoc """
  Periodically calls the Ethereum client node to check for Ethereumm's block height. Publishes
  internal events or raises alarms accordingly.

  When a new block height is received, it publishes an internal event under the topic `"ethereum_new_height"`
  with the payload `{:ethereum_new_height, height}`. The event is only published when the received
  block height is higher than the previously published height.

  When the call to the Ethereum client fails or returns an invalid responnse, it raises an
  `:ethereum_client_connection` alarm. The alarm is cleared once a valid block height is seen.

  When the call to the Ethereum client returns the same block height for longer than
  `:ethereum_stalled_sync_threshold_ms`, it raises an `:ethereum_stalled_sync` alarm.
  The alarm is cleared once the block height starts increasing again.
  """
  use GenServer
  require Logger
  alias OMG.Eth.Encoding

  @type t() :: %__MODULE__{
          check_interval_ms: pos_integer(),
          tref: reference() | nil,
          alarm_module: module(),
          event_bus: module()
          ethereum_height: integer | :error,
          last_height_increased_at: DateTime.t(),
          connection_alarm_raised: boolean(),
          stall_alarm_raised: boolean(),
        }
  defstruct check_interval_ms: 10_000,
            stall_threshold_ms: 20_000,
            tref: nil,
            alarm_module: nil,
            event_bus: nil
            ethereum_height: 0,
            last_height_increased_at: nil,
            connection_alarm_raised: false,
            stall_alarm_raised: false,

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec init(Keyword.t()) :: {:ok, t()}
  def init(opts) do
    _ = Logger.info("Starting Ethereum height monitor.")
    _ = install_alarm_handler()

    state = %__MODULE__{
      check_interval_ms: Application.fetch_env!(:omg_eth, :client_monitor_interval_ms),
      stall_threshold_ms: Application.fetch_env!(:omg_eth, :ethereum_stalled_sync_threshold_ms),
      alarm_module: Keyword.fetch!(opts, :alarm_module),
      event_bus: Keyword.fetch!(opts, :event_bus)
    }

    {:ok, tref} = :timer.send_after(state.check_interval, :check_new_height)
    {:ok, %{state | tref: tref}}
  end

  def handle_info(:check_new_height, state) do
    height = fetch_height()
    stalled? = stalled?(height, state.ethereum_height, state.last_height_increased_at, state.stall_threshold_ms)

    :ok = broadcast_on_new_height(state.event_bus, state.ethereum_height, height)
    _ = conn_alarm(state.alarm_module, state.connection_alarm_raised, height)
    _ = stall_alarm(state.alarm_module, state.stall_alarm_raised, stalled?)

    state =
      case stalled? do
        true -> state
        false -> %{state | ethereum_height: height, last_height_increased_at: DateTime.now()}
      end

    {:ok, tref} = :timer.send_after(state.check_interval, :check_new_height)
    {:noreply, %{state | tref: tref}}
  end

  # Handle alarm events from the AlarmHandler
  def handle_cast({:set_alarm, :ethereum_client_connection}, state) do
    {:noreply, %{state | connection_alarm_raised: true}}
  end

  def handle_cast({:clear_alarm, :ethereum_client_connection}, state) do
    {:noreply, %{state | connection_alarm_raised: false}}
  end

  def handle_cast({:set_alarm, :ethereum_stalled_sync}, state) do
    {:noreply, %{state | stall_alarm_raised: true}}
  end

  def handle_cast({:clear_alarm, :ethereum_stalled_sync}, state) do
    {:noreply, %{state | stall_alarm_raised: false}}
  end

  @spec stalled?() :: boolean()
  defp stalled?(height, previous_height, last_height_increased_at, stall_threshold_ms) do
    case height do
      height when is_integer(height) and height >= previous_height ->
        false

      _ ->
        DateTime.diff(DateTime.now(), last_height_increased_at, :millisecond) > stall_threshold_ms
    end
  end

  @spec fetch_height() :: non_neg_integer() | :error
  defp fetch_height() do
    case eth().get_ethereum_height() do
      {:ok, height} when is_integer(height) -> height
      _error_or_not_integer -> :error
    end
  end

  @spec eth() :: module()
  defp eth(), do: Application.get_env(:omg_child_chain, :eth_integration_module, OMG.Eth)

  @spec broadcast_on_new_height() :: :ok | {:error, term()}
  defp broadcast_on_new_height(event_bus, previous_height, height) when height > previous_height do
    apply(event_bus, :broadcast, ["ethereum_new_height", {:ethereum_new_height, height}])
  end

  defp broadcast_on_new_height(_, _, _), do: :ok

  #
  # Alarms management
  #

  defp install_alarm_handler do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(__MODULE__)
    end
  end

  # Raise or clear the :ethereum_client_connnection alarm
  @spec conn_alarm(module(), boolean(), boolean()) :: :ok | :duplicate
  defp conn_alarm(alarm_module, connection_alarm_raised, raise_alarm)

  defp conn_alarm(alarm_module, false, :error) do
    alarm_module.set(alarm_module.ethereum_client_connection(__MODULE__))
  end

  defp conn_alarm(alarm_module, true, _) do
    alarm_module.clear(alarm_module.ethereum_client_connection(__MODULE__))
  end

  defp conn_alarm(_alarm_module, _, _), do: :ok

  # Raise or clear the :ethereum_stalled_sync alarm
  @spec stall_alarm(module(), boolean(), boolean()) :: :ok | :duplicate
  defp stall_alarm(alarm_module, stall_alarm_raised, raise_alarm)

  defp stall_alarm(alarm_module, false, true) do
    alarm_module.set(alarm_module.ethereum_stalled_sync(__MODULE__))
  end

  defp stall_alarm(alarm_module, true, false) do
    alarm_module.clear(alarm_module.ethereum_stalled_sync(__MODULE__))
  end

  defp stall_alarm(_alarm_module, _, _), do: :ok
end
