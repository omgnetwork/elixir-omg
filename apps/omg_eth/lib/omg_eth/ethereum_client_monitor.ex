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

defmodule OMG.Eth.EthereumClientMonitor do
  @moduledoc """
  Process serves as a health check to Ethereum client node by maintaining a newHead subscription over websocket connection
  in order to reduce the number of RPC calls. The websocket connection is linked with this process and when it dies,
  we raise an alarm and periodically re-check the connection in order to clear the alarm.

  When the process is started we immediately make an RPC call to retrieve the height, we proceed to open a subscription towards the client.
  If the client connection drops, we get notified (`def handle_info({:EXIT, _from, _}...`) and raise an alarm and proceed with periodical health checks.
  A health check makes an RPC call and checks for correct response (is_number) - if that succeeds, there's a high probability websocket connection subscription will work as well.

  The implementation assumes ws subscription to the Ethereum client continues to work indefinitely. We'll see how that works in practice.
  """
  use GenServer
  require Logger
  alias OMG.Eth
  alias OMG.Eth.Encoding
  alias OMG.Eth.SubscriptionWorker

  @default_interval Application.get_env(:omg_eth, :client_monitor_interval_ms)
  @type t :: %__MODULE__{
          interval: pos_integer(),
          tref: reference() | nil,
          alarm_module: module(),
          raised: boolean(),
          ethereum_height: integer | :error,
          ws_url: binary() | nil,
          event_bus: module()
        }
  defstruct interval: @default_interval,
            tref: nil,
            alarm_module: nil,
            raised: false,
            ethereum_height: :error,
            ws_url: nil,
            event_bus: nil

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init([_ | _] = opts) do
    alarm_module = Keyword.fetch!(opts, :alarm_module)
    false = Process.flag(:trap_exit, true)
    _ = Logger.info("Starting Ethereum client monitor.")
    install_alarm_handler()
    ethereum_height = check()

    state = %__MODULE__{
      alarm_module: alarm_module,
      ethereum_height: ethereum_height,
      ws_url: Keyword.get(opts, :ws_url),
      event_bus: Keyword.get(opts, :event_bus)
    }

    _ = raise_clear(alarm_module, state.raised, ethereum_height)
    {:ok, state, {:continue, :ws_connect}}
  end

  # gen_event init
  def init(_args) do
    {:ok, %{}}
  end

  def handle_continue(:ws_connect, state) do
    _ = Logger.debug("Ethereum client monitor starting a WS newHeads subscription.")

    params = [listen_to: "newHeads", ws_url: state.ws_url]

    _ = SubscriptionWorker.start_link([{:event_bus, state.event_bus} | params])
    _ = raise_clear(state.alarm_module, state.raised, state.ethereum_height)
    {:noreply, state}
  rescue
    _ ->
      _ = Logger.warn("Ethereum client monitor failed at WS newHeads subscription. Health check in #{state.interval}")
      {:ok, tref} = :timer.send_after(state.interval, :health_check)
      _ = raise_clear(state.alarm_module, state.raised, :error)
      {:noreply, %{state | tref: tref}}
  end

  def handle_info({:EXIT, _from, _reason}, state) do
    # subscription died so we need to raise an alarm and start manual checks
    _ = state.alarm_module.set(state.alarm_module.ethereum_client_connection(__MODULE__))
    _ = :timer.cancel(state.tref)
    {:ok, tref} = :timer.send_after(state.interval, :health_check)
    {:noreply, %{state | tref: tref}}
  end

  def handle_info(:health_check, state) do
    ethereum_height = check()

    case is_number(ethereum_height) do
      true ->
        # we got a good response this time, restart the subscription and backoff
        # with manuall pulling
        _ = Logger.debug("Ethereum client monitor made a succesful RPC call. Proceding with WS subscription.")
        {:noreply, %{state | ethereum_height: ethereum_height}, {:continue, :ws_connect}}

      false ->
        _ = Logger.debug("Ethereum client monitor made a failed attempt RPC call. Retry in #{state.interval}.")
        {:ok, tref} = :timer.send_after(state.interval, :health_check)
        {:noreply, %{state | tref: tref, ethereum_height: ethereum_height}}
    end
  end

  # def handle_cast({:event_received, "newHeads", decoded}, state) do
  def handle_info({:internal_event_bus, :newHeads, new_heads}, state) do
    value = new_heads["params"]["result"]["number"]

    case is_binary(value) do
      true ->
        ethereum_height = Encoding.int_from_hex(value)
        _ = Logger.debug("Ethereum client monitor got a newHeads event for new Ethereum height #{ethereum_height}.")
        {:noreply, %{state | ethereum_height: ethereum_height}}

      false ->
        {:noreply, state}
    end
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
    _check_error -> :error
  end

  # if an alarm is raised, we don't have to raise it again.
  # if an alarm is cleared, we don't need to clear it again
  # we want to avoid pushing events again
  @spec raise_clear(module(), boolean(), :error | non_neg_integer()) :: :ok | :duplicate
  defp raise_clear(_alarm_module, true, :error), do: :ok

  defp raise_clear(alarm_module, false, :error),
    do: alarm_module.set(alarm_module.ethereum_client_connection(__MODULE__))

  defp raise_clear(alarm_module, true, _),
    do: alarm_module.clear(alarm_module.ethereum_client_connection(__MODULE__))

  defp raise_clear(_alarm_module, false, _), do: :ok

  defp eth, do: Application.get_env(:omg_child_chain, :eth_integration_module, Eth)

  defp install_alarm_handler do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(__MODULE__)
    end
  end
end
