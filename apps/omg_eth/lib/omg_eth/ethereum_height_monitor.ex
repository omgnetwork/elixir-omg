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

  @type t() :: %__MODULE__{
          check_interval_ms: pos_integer(),
          stall_threshold_ms: pos_integer(),
          tref: reference() | nil,
          eth_module: module(),
          alarm_module: module(),
          event_bus_module: module(),
          ethereum_height: integer(),
          synced_at: DateTime.t(),
          connection_alarm_raised: boolean(),
          stall_alarm_raised: boolean()
        }

  defstruct check_interval_ms: 10_000,
            stall_threshold_ms: 20_000,
            tref: nil,
            eth_module: nil,
            alarm_module: nil,
            event_bus_module: nil,
            ethereum_height: 0,
            synced_at: nil,
            connection_alarm_raised: false,
            stall_alarm_raised: false

  #
  # GenServer APIs
  #

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
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
      eth_module: Keyword.fetch!(opts, :eth_module),
      alarm_module: Keyword.fetch!(opts, :alarm_module),
      event_bus_module: Keyword.fetch!(opts, :event_bus_module)
    }

    {:ok, state, {:continue, :first_check}}
  end

  # We want the first check immediately upon start, but we cannot do it while the monitor
  # is not fully initialized, so we need to trigger it in a :continue instruction.
  def handle_continue(:first_check, state) do
    _ = send(self(), :check_new_height)
    {:noreply, state}
  end

  def handle_info({:ssl_closed, _}, state) do
    # eat this bug https://github.com/benoitc/hackney/issues/464
    {:noreply, state}
  end

  def handle_info(:check_new_height, state) do
    height = fetch_height(state.eth_module)
    stalled? = stalled?(height, state.ethereum_height, state.synced_at, state.stall_threshold_ms)

    :ok = broadcast_on_new_height(state.event_bus_module, height)
    _ = connection_alarm(state.alarm_module, state.connection_alarm_raised, height)
    _ = stall_alarm(state.alarm_module, state.stall_alarm_raised, stalled?)

    state = update_height(state, height)

    {:ok, tref} = :timer.send_after(state.check_interval_ms, :check_new_height)
    {:noreply, %{state | tref: tref}}
  end

  #
  # Handle incoming alarms
  #
  # These functions are called by the AlarmHandler so that this monitor process can update
  # its internal state according to the raised alarms.
  #
  def handle_cast({:set_alarm, :ethereum_connection_error}, state) do
    {:noreply, %{state | connection_alarm_raised: true}}
  end

  def handle_cast({:clear_alarm, :ethereum_connection_error}, state) do
    {:noreply, %{state | connection_alarm_raised: false}}
  end

  def handle_cast({:set_alarm, :ethereum_stalled_sync}, state) do
    {:noreply, %{state | stall_alarm_raised: true}}
  end

  def handle_cast({:clear_alarm, :ethereum_stalled_sync}, state) do
    {:noreply, %{state | stall_alarm_raised: false}}
  end

  #
  # Private functions
  #

  @spec update_height(t(), non_neg_integer() | :error) :: t()
  defp update_height(state, :error), do: state

  defp update_height(state, height) do
    case height > state.ethereum_height do
      true -> %{state | ethereum_height: height, synced_at: DateTime.utc_now()}
      false -> state
    end
  end

  @spec stalled?(non_neg_integer() | :error, non_neg_integer(), DateTime.t(), non_neg_integer()) :: boolean()
  defp stalled?(height, previous_height, synced_at, stall_threshold_ms) do
    case height do
      height when is_integer(height) and height > previous_height ->
        false

      _ ->
        DateTime.diff(DateTime.utc_now(), synced_at, :millisecond) > stall_threshold_ms
    end
  end

  @spec fetch_height(module()) :: non_neg_integer() | :error
  defp fetch_height(eth_module) do
    case eth_module.get_ethereum_height() do
      {:ok, height} ->
        height

      error ->
        _ = Logger.warn("Error retrieving Ethereum height: #{inspect(error)}")
        :error
    end
  end

  @spec broadcast_on_new_height(module(), non_neg_integer() | :error) :: :ok | {:error, term()}
  defp broadcast_on_new_height(_event_bus_module, :error), do: :ok

  # we need to publish every height we fetched so that we can re-examine blocks in case of re-orgs
  # clients subscribed to this topic need to be aware of that and if a block number repeats,
  # it needs to re-write logs, for example
  defp broadcast_on_new_height(event_bus_module, height) do
    event = OMG.Bus.Event.new({:root_chain, "ethereum_new_height"}, :ethereum_new_height, height)
    apply(event_bus_module, :broadcast, [event])
  end

  #
  # Alarms management
  #

  defp install_alarm_handler() do
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
