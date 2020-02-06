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

defmodule OMG.Eth.EthereumHeightMonitorTest do
  # async:false since `eth_integration_module` is being overridden
  use ExUnit.Case, async: false
  alias __MODULE__.EthereumClientMock
  alias OMG.Eth.EthereumHeightMonitor
  alias OMG.Eth.Event
  alias OMG.Status.Alert.Alarm

  @moduletag :capture_log

  setup_all do
    _ = Agent.start_link(fn -> 55_555 end, name: :port_holder)
    _ = Application.put_env(:omg_eth, :eth_integration_module, EthereumClientMock)
    {:ok, status_apps} = Application.ensure_all_started(:omg_status)
    {:ok, bus_apps} = Application.ensure_all_started(:omg_bus)
    apps = status_apps ++ bus_apps

    {:ok, _} = EthereumClientMock.start_link()

    on_exit(fn ->
      _ = apps |> Enum.reverse() |> Enum.each(fn app -> Application.stop(app) end)
      _ = Application.put_env(:omg_eth, :eth_integration_module, nil)
    end)
  end

  setup do
    {:ok, ethereum_height_monitor} =
      EthereumHeightMonitor.start_link(
        check_interval_ms: 10,
        stall_threshold_ms: 100,
        alarm_module: Alarm,
        event_bus: OMG.Bus
      )

    _ = Alarm.clear_all()

    on_exit(fn ->
      _ = EthereumClientMock.reset_state()
      _ = Process.sleep(10)
      true = Process.exit(ethereum_height_monitor, :kill)
    end)
  end

  #
  # Connection error
  #

  test "that the connection alarm gets raised and with EthereumConnectionError event when connection becomes unhealthy" do
    # Initialize as healthy and alarm not present
    _ = EthereumClientMock.set_faulty_response(false)
    :ok = pull_client_alarm(100, [])
    assert EthereumHeightMonitor.get_events() == {:ok, []}

    # Toggle faulty response
    _ = EthereumClientMock.set_faulty_response(true)

    # Assert the alarm and event are present
    assert pull_client_alarm(100,
             ethereum_connection_error: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumHeightMonitor}
           ) == :ok

    assert {:ok, [%Event.EthereumConnectionError{}]} = EthereumHeightMonitor.get_events()
  end

  test "that the connection alarm gets cleared and without EthereumConnectionError event when connection becomes healthy" do
    # Initialize as unhealthy
    _ = EthereumClientMock.set_faulty_response(true)

    :ok =
      pull_client_alarm(100,
        ethereum_connection_error: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumHeightMonitor}
      )

    assert {:ok, [%Event.EthereumConnectionError{}]} = EthereumHeightMonitor.get_events()

    # Toggle healthy response
    _ = EthereumClientMock.set_faulty_response(false)

    # Assert the alarm and event are no longer present
    assert pull_client_alarm(100, []) == :ok
    assert EthereumHeightMonitor.get_events() == {:ok, []}
  end

  #
  # Stalling sync
  #

  test "that the stall alarm gets raised and with EthereumStalledSync event when block height stalls" do
    # Initialize as healthy and alarm not present
    _ = EthereumClientMock.set_stalled(false)
    :ok = pull_client_alarm(200, [])
    assert EthereumHeightMonitor.get_events() == {:ok, []}

    # Toggle stalled height
    _ = EthereumClientMock.set_stalled(true)

    # Assert alarm now present
    assert pull_client_alarm(200,
             ethereum_stalled_sync: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumHeightMonitor}
           ) == :ok

    assert {:ok, [%Event.EthereumStalledSync{}]} = EthereumHeightMonitor.get_events()
  end

  test "that the stall alarm gets cleared and without EthereumStalledSync event when block height unstalls" do
    # Initialize as unhealthy
    _ = EthereumClientMock.set_stalled(true)

    :ok =
      pull_client_alarm(300, ethereum_stalled_sync: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumHeightMonitor})

    assert {:ok, [%Event.EthereumStalledSync{}]} = EthereumHeightMonitor.get_events()

    # Toggle unstalled height
    _ = EthereumClientMock.set_stalled(false)

    # Assert alarm no longer present
    assert pull_client_alarm(300, []) == :ok
    assert EthereumHeightMonitor.get_events() == {:ok, []}
  end

  defp pull_client_alarm(0, _), do: {:cant_match, Alarm.all()}

  defp pull_client_alarm(n, match) do
    case Alarm.all() do
      ^match ->
        :ok

      _ ->
        Process.sleep(50)
        pull_client_alarm(n - 1, match)
    end
  end

  defmodule EthereumClientMock do
    @moduledoc """
    Mocking the ETH module integration point.
    """
    use GenServer

    @initial_state %{height: 0, faulty: false, stalled: false}

    def start_link, do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

    def get_ethereum_height, do: GenServer.call(__MODULE__, :get_ethereum_height)

    def set_faulty_response(faulty), do: GenServer.call(__MODULE__, {:set_faulty_response, faulty})

    def set_long_response(milliseconds), do: GenServer.call(__MODULE__, {:set_long_response, milliseconds})

    def set_stalled(stalled), do: GenServer.call(__MODULE__, {:set_stalled, stalled})

    def reset_state(), do: GenServer.call(__MODULE__, :reset_state)

    def stop, do: GenServer.stop(__MODULE__, :normal)

    def init(_), do: {:ok, @initial_state}

    def handle_call(:reset_state, _, _state), do: {:reply, :ok, @initial_state}

    def handle_call({:set_faulty_response, true}, _, state), do: {:reply, :ok, %{state | faulty: true}}
    def handle_call({:set_faulty_response, false}, _, state), do: {:reply, :ok, %{state | faulty: false}}

    def handle_call({:set_long_response, milliseconds}, _, state) do
      {:reply, :ok, Map.merge(%{long_response: milliseconds}, state)}
    end

    def handle_call({:set_stalled, true}, _, state), do: {:reply, :ok, %{state | stalled: true}}
    def handle_call({:set_stalled, false}, _, state), do: {:reply, :ok, %{state | stalled: false}}

    # Heights management

    def handle_call(:get_ethereum_height, _, %{faulty: true} = state) do
      {:reply, :error, state}
    end

    def handle_call(:get_ethereum_height, _, %{long_response: milliseconds} = state) when not is_nil(milliseconds) do
      _ = Process.sleep(milliseconds)
      {:reply, {:ok, state.height}, %{state | height: next_height(state.height, state.stalled)}}
    end

    def handle_call(:get_ethereum_height, _, state) do
      {:reply, {:ok, state.height}, %{state | height: next_height(state.height, state.stalled)}}
    end

    defp next_height(height, false), do: height + 1
    defp next_height(height, true), do: height
  end
end
