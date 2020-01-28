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
  Monitors the Ethereum height and raises an alarm when new root chain blocks
  are not received in a timely manner.

  Note that this module monitors valid block numbers only. Errors are ignored.
  To monitor connectivity errors, consider using `OMG.Eth.EthereumClientMonitor`.
  """
  use GenServer
  require Logger

  alias OMG.Eth.EthereumClientMonitor
  alias OMG.Eth.EthereumHeight

  @height_monitor __MODULE__

  @default_interval Application.get_env(:omg_eth, :ethereum_stalled_sync_check_interval_ms)

  @type t :: %__MODULE__{
          interval: pos_integer(),
          tref: reference() | nil,
          alarm_module: module(),
          raised: boolean(),
          last_checked_height: non_neg_integer()
        }
  defstruct interval: @default_interval,
            tref: nil,
            alarm_module: nil,
            raised: false,
            last_checked_height: 0

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(opts) do
    _ = Logger.info("Starting Ethereum height monitor.")
    _ = install_alarm_handler()

    state = %__MODULE__{
      alarm_module: Keyword.fetch!(opts, :alarm_module)
    }

    {:ok, state, {:continue, :start_check}}
  end

  def handle_continue(:start_check, state) do
    ethereum_height = EthereumHeight.get()
    stalled = stalled?(ethereum_height, state.last_checked_height)
    _ = raise_or_clear(state.alarm_module, state.raised, stalled)

    {:ok, tref} = :timer.send_after(state.interval, :check_height)
    {:ok, %{state | tref: tref, last_checked_height: ethereum_height}}
  end

  def handle_info(:check_height, state) do
    ethereum_height = EthereumHeight.get()
    stalled = stalled?(ethereum_height, state.last_checked_height)
    _ = raise_or_clear(state.alarm_module, state.raised, stalled)

    {:ok, tref} = :timer.send_after(state.interval, :check_height)
    {:noreply, %{state | tref: tref, last_checked_height: ethereum_height}}
  end

  # Handles alarm events from AlarmHandler
  def handle_cast(:clear_alarm, state) do
    {:noreply, %{state | raised: false}}
  end

  def handle_cast(:set_alarm, state) do
    {:noreply, %{state | raised: true}}
  end

  defmodule AlarmHandler do
    @moduledoc """
    Listens for :ethereum_stalled_sync alarm, triggers an EthereumClientMonitor restart,
    and reflect the state back to EthereumHeightMonitor.
    """
    use GenServer

    def init(_args) do
      {:ok, %{}}
    end

    def handle_call(_request, state), do: {:ok, :ok, state}

    def handle_event({:set_alarm, {:ethereum_stalled_sync, %{reporter: @height_monitor}}}, state) do
      _ = Logger.warn(":ethereum_stalled_sync alarm raised. Restarting EthereumHeightMonitor.")
      :ok = GenServer.stop(EthereumClientMonitor)
      :ok = GenServer.cast(@height_monitor, :set_alarm)
      {:ok, state}
    end

    def handle_event({:clear_alarm, {:ethereum_stalled_sync, %{reporter: @height_monitor}}}, state) do
      _ = Logger.warn(":ethereum_stalled_sync alarm cleared.")
      :ok = GenServer.cast(@height_monitor, :clear_alarm)
      {:ok, state}
    end

    def handle_event(event, state) do
      _ = Logger.info("EthereumHeightMonitor.AlarmHandler got event: #{inspect(event)}. Ignoring.")
      {:ok, state}
    end
  end

  # Consider the sync as healthy if the height increases between intervals.
  # Ignoring any upstream errors, anything else is considered a stall.
  defp stalled?(:error, _last_checked_height), do: :ignore

  defp stalled?(_height, :error), do: :ignore

  defp stalled?(height, last_checked_height) when height > last_checked_height, do: false

  defp stalled?(_height, _last_checked_height), do: true

  # if an alarm is raised, we don't have to raise it again.
  # if an alarm is cleared, we don't need to clear it again
  # we want to avoid pushing events again
  @spec raise_or_clear(module(), boolean(), boolean() | :ignore) :: :ok | :duplicate
  defp raise_or_clear(_alarm_module, _, :ignore), do: :ok

  defp raise_or_clear(alarm_module, false, true),
    do: alarm_module.set(alarm_module.ethereum_stalled_sync(__MODULE__))

  defp raise_or_clear(alarm_module, true, false),
    do: alarm_module.clear(alarm_module.ethereum_stalled_sync(__MODULE__))

  defp raise_or_clear(_alarm_module, _, _), do: :ok

  defp install_alarm_handler do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), AlarmHandler) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(AlarmHandler)
    end
  end
end
