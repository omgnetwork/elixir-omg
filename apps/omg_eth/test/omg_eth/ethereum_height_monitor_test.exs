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
  @moduledoc false
  use ExUnit.Case, async: false
  alias __MODULE__.EthereumClientMock
  alias OMG.Eth.EthereumHeightMonitor
  alias OMG.Status.Alert.Alarm

  @moduletag :capture_log

  setup_all do
    _ = Agent.start_link(fn -> 55_555 end, name: :port_holder)
    _ = Application.put_env(:omg_child_chain, :eth_integration_module, EthereumClientMock)
    {:ok, status_apps} = Application.ensure_all_started(:omg_status)
    {:ok, bus_apps} = Application.ensure_all_started(:omg_bus)
    apps = status_apps ++ bus_apps

    {:ok, _} = EthereumClientMock.start_link()

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(fn app -> Application.stop(app) end)
      Application.put_env(:omg_child_chain, :eth_integration_module, nil)
    end)
  end

  setup do
    {:ok, ethereum_height_monitor} = EthereumHeightMonitor.start_link(alarm_module: Alarm, event_bus: OMG.Bus)
    # Alarm.clear_all()

    # on_exit(fn ->
    #   :sys.replace_state(Process.whereis(EthereumClientMock), fn _ -> %{} end)
    #   _ = Process.sleep(10)
    #   true = Process.exit(ethereum_height_monitor, :kill)
    # end)

    :ok
  end

  test "that the connection alarm gets raised when connection is unhealthy" do
    # pid = Process.whereis(EthereumHeightMonitor)
    # assert %{connection_alarm_raised: false} = :sys.get_state(EthereumHeightMonitor)

    # alarm = [ethereum_connection_error: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumHeightMonitor}]

    # assert ^alarm = Alarm.all()
    # assert Alarm.all() == alarm


    # assert %{connection_alarm_raised: true} = :sys.get_state(EthereumHeightMonitor)
    # # eventually, the connection should recover
    # assert_receive({:trace, ^pid, :receive, {:"$gen_cast", :clear_alarm}}, 100)
  end

  # test "that alarm gets raised if there's no ethereum client running and cleared when it's running" do
  #   ### We mimick the complete failure of the ethereum client
  #   ### by first shutting down the websocket server that we were connected to - that starts healthchecks.
  #   ### We start returning error responses from the RPC servers that we're doing health checks towards.
  #   ### That (eventually) raises an alarm.
  #   ### We continue by re-starting the mocked RPC server and websocket server and check if the alarm
  #   ## was removed.

  #   _ = WebSockexServerMock.shutdown(server_ref)

  #   true = is_pid(Process.whereis(EthereumHeightMonitor))

  #   :ok =
  #     pull_client_alarm(300,
  #       ethereum_connection_error: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumHeightMonitor}
  #     )

  #   :sys.replace_state(Process.whereis(EthereumClientMock), fn _ -> %{} end)

  #   {:ok, {server_ref, ^websocket_url}} = WebSockexServerMock.restart(websocket_url)
  #   :ok = pull_client_alarm(400, [])
  #   WebSockexServerMock.shutdown(server_ref)
  # end

  # test "that we don't overflow the message queue with timers when Eth client needs time to respond" do
  #   ### We mimick the complete failure of the ethereum client
  #   ### by first shutting down the websocket server that we were connected to - that starts healthchecks.
  #   ### We start returning error responses from the RPC servers that we're doing health checks towards.
  #   ### That (eventually) raises an alarm.
  #   ### We make sure that our timer doesn't bomb the process's mailbox if requests take too long.
  #   ### We continue by re-starting the mocked RPC server and websocket server and check if the alarm
  #   ## was removed.

  #   WebSockexServerMock.shutdown(server_ref)
  #   EthereumClientMock.set_faulty_response()
  #   EthereumClientMock.set_long_response(1500)
  #   pid = Process.whereis(EthereumHeightMonitor)
  #   true = is_pid(pid)

  #   :ok =
  #     pull_client_alarm(100,
  #       ethereum_connection_error: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumHeightMonitor}
  #     )

  #   {:message_queue_len, 0} = Process.info(pid, :message_queue_len)
  #   :sys.replace_state(Process.whereis(EthereumClientMock), fn _ -> %{} end)
  #   {:ok, {server_ref, ^websocket_url}} = WebSockexServerMock.restart(websocket_url)
  #   :ok = pull_client_alarm(400, [])
  #   WebSockexServerMock.shutdown(server_ref)
  # rescue
  #   reason ->
  #     raise("message_queue_not_empty #{inspect(reason)}")
  # end

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

    def start_link, do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

    def get_ethereum_height, do: GenServer.call(__MODULE__, :get_ethereum_height)

    def set_faulty_response, do: GenServer.call(__MODULE__, :set_faulty_response)

    def set_long_response(milliseconds), do: GenServer.call(__MODULE__, {:set_long_response, milliseconds})

    def stop, do: GenServer.stop(__MODULE__, :normal)

    def init(_), do: {:ok, %{height: 0}}

    def handle_call(:set_faulty_response, _, _state), do: {:reply, :ok, %{error: true}}

    def handle_call(:get_ethereum_height, _, %{long_response: miliseconds} = state) do
      _ = Process.sleep(miliseconds)
      {:reply, {:ok, 1}, state}
    end

    def handle_call(:get_ethereum_height, _, %{error: true} = state), do: {:reply, :error, state}
    def handle_call(:get_ethereum_height, _, state), do: {:reply, {:ok, state.height}, %{state | height: state.height +1 }}

    def handle_call({:set_long_response, milliseconds}, _, state),
      do: {:reply, :ok, Map.merge(%{long_response: milliseconds}, state)}
  end
end
