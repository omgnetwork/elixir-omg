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
  alias OMG.Status.Alert.Alarm

  @moduletag :capture_log

  setup_all do
    _ = Agent.start_link(fn -> 55_555 end, name: :port_holder)
    {:ok, status_apps} = Application.ensure_all_started(:omg_status)
    {:ok, bus_apps} = Application.ensure_all_started(:omg_bus)
    apps = status_apps ++ bus_apps

    {:ok, _} = EthereumClientMock.start_link()

    on_exit(fn ->
      _ = apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    end)
  end

  setup do
    check_interval_ms = 10
    stall_threshold_ms = 100

    {:ok, monitor} =
      EthereumHeightMonitor.start_link(
        check_interval_ms: check_interval_ms,
        stall_threshold_ms: stall_threshold_ms,
        eth_module: EthereumClientMock,
        alarm_module: Alarm,
        event_bus_module: OMG.Bus
      )

    _ = Alarm.clear_all()

    _ =
      on_exit(fn ->
        _ = EthereumClientMock.reset_state()
        _ = Process.sleep(10)
        true = Process.exit(monitor, :kill)
      end)

    {:ok,
     %{
       monitor: monitor,
       check_interval_ms: check_interval_ms,
       stall_threshold_ms: stall_threshold_ms
     }}
  end

  #
  # Internal event publishing
  #

  test "that an ethereum_new_height event is published when the height increases", context do
    _ = EthereumClientMock.set_stalled(false)

    {:ok, listener} = __MODULE__.EventBusListener.start(self())
    on_exit(fn -> GenServer.stop(listener) end)

    assert_receive(:got_ethereum_new_height, Kernel.trunc(context.check_interval_ms * 10))
  end

  #
  # Connection error
  #

  test "that the connection alarm gets raised when connection becomes unhealthy" do
    # Initialize as healthy and alarm not present
    _ = EthereumClientMock.set_faulty_response(false)
    :ok = pull_client_alarm([], 100)

    # Toggle faulty response
    _ = EthereumClientMock.set_faulty_response(true)

    # Assert the alarm and event are present
    assert pull_client_alarm(
             [ethereum_connection_error: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumHeightMonitor}],
             100
           ) == :ok
  end

  test "that the connection alarm gets cleared when connection becomes healthy" do
    # Initialize as unhealthy
    _ = EthereumClientMock.set_faulty_response(true)

    :ok =
      pull_client_alarm(
        [ethereum_connection_error: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumHeightMonitor}],
        100
      )

    # Toggle healthy response
    _ = EthereumClientMock.set_faulty_response(false)

    # Assert the alarm and event are no longer present
    assert pull_client_alarm([], 100) == :ok
  end

  #
  # Stalling sync
  #

  test "that the stall alarm gets raised when block height stalls" do
    # Initialize as healthy and alarm not present
    _ = EthereumClientMock.set_stalled(false)
    :ok = pull_client_alarm([], 200)

    # Toggle stalled height
    _ = EthereumClientMock.set_stalled(true)

    # Assert alarm now present
    assert pull_client_alarm(
             [ethereum_stalled_sync: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumHeightMonitor}],
             200
           ) == :ok
  end

  test "that the stall alarm gets cleared when block height unstalls" do
    # Initialize as unhealthy
    _ = EthereumClientMock.set_stalled(true)

    :ok =
      pull_client_alarm([ethereum_stalled_sync: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumHeightMonitor}], 300)

    # Toggle unstalled height
    _ = EthereumClientMock.set_stalled(false)

    # Assert alarm no longer present
    assert pull_client_alarm([], 300) == :ok
  end

  defp pull_client_alarm(_, 0), do: {:cant_match, Alarm.all()}

  defp pull_client_alarm(match, n) do
    case Alarm.all() do
      ^match ->
        :ok

      _ ->
        Process.sleep(50)
        pull_client_alarm(match, n - 1)
    end
  end

  #
  # Test submodules
  #

  defmodule EthereumClientMock do
    @moduledoc """
    Mocking the ETH module integration point.
    """
    use GenServer

    @initial_state %{height: 0, faulty: false, stalled: false}

    def start_link(), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

    def get_ethereum_height(), do: GenServer.call(__MODULE__, :get_ethereum_height)

    def set_faulty_response(faulty), do: GenServer.call(__MODULE__, {:set_faulty_response, faulty})

    def set_long_response(milliseconds), do: GenServer.call(__MODULE__, {:set_long_response, milliseconds})

    def set_stalled(stalled), do: GenServer.call(__MODULE__, {:set_stalled, stalled})

    def reset_state(), do: GenServer.call(__MODULE__, :reset_state)

    def stop(), do: GenServer.stop(__MODULE__, :normal)

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

  defmodule EventBusListener do
    use GenServer

    def start(parent), do: GenServer.start(__MODULE__, parent)

    def init(parent) do
      :ok = OMG.Bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)
      {:ok, parent}
    end

    def handle_info({:internal_event_bus, :ethereum_new_height, _height}, parent) do
      _ = send(parent, :got_ethereum_new_height)
      {:noreply, parent}
    end
  end
end
