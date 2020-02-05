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

defmodule OMG.Eth.EthereumClientMonitorTest do
  @moduledoc false

  use ExUnit.Case, async: false
  alias __MODULE__.EthereumClientMock
  alias __MODULE__.WebSockexMockTestSocket
  alias __MODULE__.WebSockexServerMock
  alias OMG.Eth.EthereumClientMonitor
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
    {:ok, {server_ref, websocket_url}} = WebSockexServerMock.start()
    {:ok, ethereum_client_monitor} = EthereumClientMonitor.start_link(alarm_module: Alarm, ws_url: websocket_url)
    Alarm.clear_all()

    on_exit(fn ->
      :sys.replace_state(Process.whereis(EthereumClientMock), fn _ -> %{} end)
      _ = WebSockexServerMock.shutdown(server_ref)
      _ = Process.sleep(10)
      true = Process.exit(ethereum_client_monitor, :kill)
    end)

    %{server_ref: server_ref, websocket_url: websocket_url}
  end

  test "that alarms get raised when we kill the connection", %{
    server_ref: _server_ref,
    websocket_url: _websocket_url
  } do
    pid = Process.whereis(EthereumClientMonitor)
    %{raised: false} = :sys.get_state(EthereumClientMonitor)
    {:links, links} = Process.info(pid, :links)
    exclude_test_pid = self()

    [ws_connection] =
      Enum.filter(links, fn
        ^exclude_test_pid -> false
        _ -> true
      end)

    :erlang.trace(pid, true, [:receive])
    true = Process.exit(ws_connection, :testkill)
    assert_receive {:trace, ^pid, :receive, {:EXIT, ^ws_connection, :testkill}}
    assert_receive {:trace, ^pid, :receive, {:"$gen_cast", :set_alarm}}

    alarm = [ethereum_client_connection: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumClientMonitor}]

    ^alarm = Alarm.all()

    %{raised: true} = :sys.get_state(EthereumClientMonitor)
    # eventually, the connection should recover
    assert_receive({:trace, ^pid, :receive, {:"$gen_cast", :clear_alarm}}, 100)
  end

  test "that alarm gets raised if there's no ethereum client running and cleared when it's running", %{
    server_ref: server_ref,
    websocket_url: websocket_url
  } do
    ### We mimick the complete failure of the ethereum client
    ### by first shutting down the websocket server that we were connected to - that starts healthchecks.
    ### We start returning error responses from the RPC servers that we're doing health checks towards.
    ### That (eventually) raises an alarm.
    ### We continue by re-starting the mocked RPC server and websocket server and check if the alarm
    ## was removed.

    _ = WebSockexServerMock.shutdown(server_ref)

    true = is_pid(Process.whereis(EthereumClientMonitor))

    :ok =
      pull_client_alarm(300,
        ethereum_client_connection: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumClientMonitor}
      )

    :sys.replace_state(Process.whereis(EthereumClientMock), fn _ -> %{} end)

    {:ok, {server_ref, ^websocket_url}} = WebSockexServerMock.restart(websocket_url)
    :ok = pull_client_alarm(400, [])
    WebSockexServerMock.shutdown(server_ref)
  end

  test "that we don't overflow the message queue with timers when Eth client needs time to respond", %{
    server_ref: server_ref,
    websocket_url: websocket_url
  } do
    ### We mimick the complete failure of the ethereum client
    ### by first shutting down the websocket server that we were connected to - that starts healthchecks.
    ### We start returning error responses from the RPC servers that we're doing health checks towards.
    ### That (eventually) raises an alarm.
    ### We make sure that our timer doesn't bomb the process's mailbox if requests take too long.
    ### We continue by re-starting the mocked RPC server and websocket server and check if the alarm
    ## was removed.

    WebSockexServerMock.shutdown(server_ref)
    EthereumClientMock.set_faulty_response()
    EthereumClientMock.set_long_response(1500)
    pid = Process.whereis(EthereumClientMonitor)
    true = is_pid(pid)

    :ok =
      pull_client_alarm(100,
        ethereum_client_connection: %{node: :nonode@nohost, reporter: OMG.Eth.EthereumClientMonitor}
      )

    _ = Process.sleep(100)
    {:message_queue_len, 0} = Process.info(pid, :message_queue_len)
    :sys.replace_state(Process.whereis(EthereumClientMock), fn _ -> %{} end)
    {:ok, {server_ref, ^websocket_url}} = WebSockexServerMock.restart(websocket_url)
    :ok = pull_client_alarm(400, [])
    WebSockexServerMock.shutdown(server_ref)
  rescue
    reason ->
      raise("message_queue_not_empty #{inspect(reason)}")
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
    def start_link, do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

    def get_ethereum_height, do: GenServer.call(__MODULE__, :get_ethereum_height)

    def set_faulty_response, do: GenServer.call(__MODULE__, :set_faulty_response)

    def set_long_response(milliseconds), do: GenServer.call(__MODULE__, {:set_long_response, milliseconds})

    def stop, do: GenServer.stop(__MODULE__, :normal)

    def init(_), do: {:ok, %{}}

    def handle_call(:set_faulty_response, _, _state), do: {:reply, :ok, %{error: true}}

    def handle_call(:get_ethereum_height, _, %{long_response: miliseconds} = state) do
      _ = Process.sleep(miliseconds)
      {:reply, {:ok, 1}, state}
    end

    def handle_call(:get_ethereum_height, _, %{error: true} = state), do: {:reply, :error, state}
    def handle_call(:get_ethereum_height, _, state), do: {:reply, {:ok, 1}, state}

    def handle_call({:set_long_response, milliseconds}, _, state),
      do: {:reply, :ok, Map.merge(%{long_response: milliseconds}, state)}
  end

  defmodule WebSockexServerMock do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    match _ do
      send_resp(conn, 200, "Hello from plug")
    end

    def start() do
      ref = make_ref()
      port = Agent.get_and_update(:port_holder, fn state -> {state, state + 1} end)
      websocket_url = start_server(port, ref)
      {:ok, {ref, websocket_url}}
    end

    def restart("ws://localhost:" <> <<port::bytes-size(5)>> <> "/ws" = websocket_url) do
      ref = make_ref()
      opts = [dispatch: dispatch(), port: String.to_integer(port), ref: ref]
      :ok = wait_until_restart(opts, 100)
      {:ok, {ref, websocket_url}}
    end

    def shutdown(ref) do
      Plug.Adapters.Cowboy.shutdown(ref)
    end

    defp dispatch do
      [{:_, [{"/ws", WebSockexMockTestSocket, []}]}]
    end

    defp start_server(port, ref) do
      opts = [dispatch: dispatch(), port: port, ref: ref]

      case Plug.Adapters.Cowboy.http(__MODULE__, [], opts) do
        {:error, :eaddrinuse} ->
          start_server(Agent.get_and_update(:port_holder, fn state -> {state, state + 1} end), ref)

        {:ok, _} ->
          "ws://localhost:#{port}/ws"
      end
    end

    defp wait_until_restart(opts, 0), do: Plug.Adapters.Cowboy.http(__MODULE__, [], opts)

    defp wait_until_restart(opts, index) do
      case Plug.Adapters.Cowboy.http(__MODULE__, [], opts) do
        {:ok, _} ->
          :ok

        {:error, :eaddrinuse} ->
          Process.sleep(10)
          wait_until_restart(opts, index - 1)
      end
    end
  end

  defmodule WebSockexMockTestSocket do
    @behaviour :cowboy_websocket_handler

    def init(_, _req, _) do
      {:upgrade, :protocol, :cowboy_websocket}
    end

    def terminate(_, _, _), do: :ok

    def websocket_init(_, req, _) do
      {:ok, req, %{}}
    end

    def websocket_terminate(_, _, _) do
      :ok
    end

    def websocket_handle({:text, _body}, req, state) do
      response = Jason.encode!(%{"params" => %{"result" => %{"number" => "0x77be11", "hash" => "0x1234"}}})
      {:reply, {:text, response}, req, state}
    end

    def websocket_info(_, req, state), do: {:ok, req, state}
  end
end
