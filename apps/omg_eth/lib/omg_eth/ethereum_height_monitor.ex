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
  `:ethereum_connection_error` alarm. The alarm is cleared once a valid block height is seen.

  When the call to the Ethereum client returns the same block height for longer than
  `:ethereum_stalled_sync_threshold_ms`, it raises an `:ethereum_stalled_sync` alarm.
  The alarm is cleared once the block height starts increasing again.
  """
  use GenServer
  require Logger
  alias OMG.Eth.Event

  @type events_t() :: [Event.t()]

  @type t() :: %__MODULE__{
          check_interval_ms: pos_integer(),
          stall_threshold_ms: pos_integer(),
          tref: reference() | nil,
          alarm_module: module(),
          event_bus: module(),
          ethereum_height: integer(),
          synced_at: DateTime.t(),
          connection_alarm_raised: boolean(),
          stall_alarm_raised: boolean(),
          events: events_t()
        }

  defstruct check_interval_ms: 10_000,
            stall_threshold_ms: 20_000,
            tref: nil,
            alarm_module: nil,
            event_bus: nil,
            ethereum_height: 0,
            synced_at: nil,
            connection_alarm_raised: false,
            stall_alarm_raised: false,
            events: []

  #
  # GenServer APIs
  #

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Return current events that are associated with `EthereumHeightMonitor`.
  """
  @spec get_events() :: {:ok, events_t()}
  def get_events() do
    GenServer.call(__MODULE__, :get_events)
  end

  #
  # GenServer behaviors
  #

  def init(opts) do
    _ = Logger.info("Starting Ethereum height monitor.")
    _ = install_alarm_handler()

    state = %__MODULE__{
      check_interval_ms: Keyword.fetch!(opts, :check_interval_ms),
      stall_threshold_ms: Keyword.fetch!(opts, :stall_threshold_ms),
      synced_at: DateTime.utc_now(),
      alarm_module: Keyword.fetch!(opts, :alarm_module),
      event_bus: Keyword.fetch!(opts, :event_bus)
    }

    {:ok, tref} = :timer.send_after(state.check_interval_ms, :check_new_height)
    {:ok, %{state | tref: tref}}
  end

  def handle_info(:check_new_height, state) do
    height = fetch_height()
    stalled? = stalled?(height, state.ethereum_height, state.synced_at, state.stall_threshold_ms)

    :ok = broadcast_on_new_height(state.event_bus, state.ethereum_height, height)
    _ = connection_alarm(state.alarm_module, state.connection_alarm_raised, height)
    _ = stall_alarm(state.alarm_module, state.stall_alarm_raised, stalled?)

    state =
      case height > state.ethereum_height do
        true -> %{state | ethereum_height: height, synced_at: DateTime.utc_now()}
        false -> state
      end

    {:ok, tref} = :timer.send_after(state.check_interval_ms, :check_new_height)
    {:noreply, %{state | tref: tref}}
  end

  def handle_call(:get_events, _from, state) do
    {:reply, {:ok, state.events}, state}
  end

  #
  # Handle incoming alarms
  #
  # These functions are called by the AlarmHandler so that this monitor process can update
  # its internal state according to the raised alarms. Mainly these handlers do 2 things:
  #
  # 1. Reflect the internal state so that it does not re-raise an existing alarm
  # 2. Maintain the list of events that the alarm corresponds to
  #
  def handle_cast({:set_alarm, :ethereum_connection_error}, state) do
    events = [%Event.EthereumConnectionError{} | state.events]
    {:noreply, %{state | connection_alarm_raised: true, events: events}}
  end

  def handle_cast({:clear_alarm, :ethereum_connection_error}, state) do
    events = clear_events(state.events, Event.EthereumConnectionError)
    {:noreply, %{state | connection_alarm_raised: false, events: events}}
  end

  def handle_cast({:set_alarm, :ethereum_stalled_sync}, state) do
    events = [
      %Event.EthereumStalledSync{
        ethereum_height: state.ethereum_height,
        synced_at: state.synced_at
      }
      | state.events
    ]

    {:noreply, %{state | stall_alarm_raised: true, events: events}}
  end

  def handle_cast({:clear_alarm, :ethereum_stalled_sync}, state) do
    events = clear_events(state.events, Event.EthereumStalledSync)
    {:noreply, %{state | stall_alarm_raised: false, events: events}}
  end

  #
  # Private functions
  #

  @spec stalled?(non_neg_integer() | :error, non_neg_integer(), DateTime.t(), non_neg_integer()) :: boolean()
  defp stalled?(height, previous_height, synced_at, stall_threshold_ms) do
    case height do
      height when is_integer(height) and height > previous_height ->
        false

      _ ->
        DateTime.diff(DateTime.utc_now(), synced_at, :millisecond) > stall_threshold_ms
    end
  end

  @spec fetch_height() :: non_neg_integer() | :error
  defp fetch_height() do
    case eth().get_ethereum_height() do
      {:ok, height} ->
        height

      error ->
        _ = Logger.warn("Error retrieving Ethereum height: #{inspect(error)}")
        :error
    end
  end

  @spec eth() :: module()
  defp eth(), do: Application.get_env(:omg_eth, :eth_integration_module, OMG.Eth)

  @spec broadcast_on_new_height(module(), non_neg_integer(), non_neg_integer() | :error) :: :ok | {:error, term()}
  defp broadcast_on_new_height(_event_bus, _previous_height, :error), do: :ok

  defp broadcast_on_new_height(event_bus, previous_height, height) when height > previous_height do
    apply(event_bus, :broadcast, ["ethereum_new_height", {:ethereum_new_height, height}])
  end

  defp broadcast_on_new_height(_, _, _), do: :ok

  @spec clear_events(events_t(), module()) :: events_t()
  defp clear_events(events, module) do
    Enum.reject(events, fn %struct_module{} -> struct_module == module end)
  end

  #
  # Alarms management
  #

  defp install_alarm_handler do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__.AlarmHandler) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(__MODULE__.AlarmHandler)
    end
  end

  # Raise or clear the :ethereum_client_connnection alarm
  @spec connection_alarm(module(), boolean(), non_neg_integer() | :error) :: :ok | :duplicate
  defp connection_alarm(alarm_module, connection_alarm_raised, raise_alarm)

  defp connection_alarm(alarm_module, false, :error) do
    alarm_module.set(alarm_module.ethereum_connection_error(__MODULE__))
  end

  defp connection_alarm(alarm_module, true, height) when is_integer(height) do
    alarm_module.clear(alarm_module.ethereum_connection_error(__MODULE__))
  end

  defp connection_alarm(_alarm_module, _, _), do: :ok

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
