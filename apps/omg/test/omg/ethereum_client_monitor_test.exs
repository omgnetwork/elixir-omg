# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.EthereumClientMonitorTest do
  @moduledoc false

  use ExUnit.Case, async: false
  alias __MODULE__.Mock
  alias __MODULE__.WebSockex.ServerMock
  alias OMG.Alert.Alarm
  alias OMG.Alert.AlarmHandler
  alias OMG.EthereumClientMonitor

  setup_all do
    :ok = AlarmHandler.install()

    on_exit(fn ->
      Application.put_env(:omg_child_chain, :eth_integration_module, nil)
    end)
  end

  setup do
    Application.put_env(:omg_child_chain, :eth_integration_module, Mock)
    Mock.start_link()
    {:ok, {server_ref, websocket_url}} = ServerMock.start(self())
    {:ok, ethereum_client_monitor} = EthereumClientMonitor.start_link(alarm_module: Alarm, ws_url: websocket_url)
    Alarm.clear_all()

    on_exit(fn ->
      # Mock.stop()
      ServerMock.shutdown(server_ref)
      true = Process.exit(ethereum_client_monitor, :kill)
      Application.put_env(:omg_child_chain, :eth_integration_module, nil)
    end)

    %{server_ref: server_ref, websocket_url: websocket_url}
  end

  test "that alarm gets raised if there's no ethereum client running", %{
    server_ref: server_ref,
    websocket_url: _websocket_url
  } do
    ServerMock.shutdown(server_ref)
    true = is_pid(Process.whereis(EthereumClientMonitor))

    :ok =
      pull_client_alarm(400, [
        %{
          details: %{node: Node.self(), reporter: EthereumClientMonitor},
          id: :ethereum_client_connection
        }
      ])

    Mock.clear_faulty_response()
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
    ServerMock.shutdown(server_ref)

    true = is_pid(Process.whereis(EthereumClientMonitor))

    :ok =
      pull_client_alarm(300, [
        %{
          details: %{node: Node.self(), reporter: EthereumClientMonitor},
          id: :ethereum_client_connection
        }
      ])

    _ = Mock.set_ok_response()
    {:ok, {_server_ref, ^websocket_url}} = ServerMock.start(self(), websocket_url)
    :ok = pull_client_alarm(400, [])
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
    ServerMock.shutdown(server_ref)

    Mock.set_faulty_response()

    Mock.set_long_response(5500)

    pid = Process.whereis(EthereumClientMonitor)
    true = is_pid(pid)

    _ =
      pull_client_alarm(100, [
        %{
          details: %{node: Node.self(), reporter: EthereumClientMonitor},
          id: :ethereum_client_connection
        }
      ])

    {:message_queue_len, 0} = Process.info(pid, :message_queue_len)
    _ = Mock.clear_long_response()
    _ = Mock.set_ok_response()
    {:ok, {_server_ref, ^websocket_url}} = ServerMock.start(self(), websocket_url)
    :ok = pull_client_alarm(400, [])
    Mock.clear_long_response()
  rescue
    reason ->
      _ = Mock.clear_long_response()
      raise("message_queue_not_empty #{inspect(reason)}")
  end

  defp pull_client_alarm(0, _), do: {:cant_match, Alarm.all()}

  defp pull_client_alarm(n, match) do
    case Alarm.all() do
      ^match ->
        :ok

      _ ->
        Process.sleep(10)
        pull_client_alarm(n - 1, match)
    end
  end

  defmodule Mock do
    @moduledoc """
    Mocking the ETH module integration point.
    """
    use GenServer
    def start_link, do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

    def get_ethereum_height do
      GenServer.call(__MODULE__, :get_ethereum_height)
    end

    def set_faulty_response, do: GenServer.call(__MODULE__, :set_faulty_response)
    def clear_faulty_response, do: GenServer.call(__MODULE__, :clear_faulty_response)
    def set_long_response(milliseconds), do: GenServer.call(__MODULE__, {:set_long_response, milliseconds})
    def clear_long_response, do: GenServer.call(__MODULE__, :clear_long_response)
    def set_ok_response, do: GenServer.call(__MODULE__, :set_ok_response)
    def stop, do: GenServer.stop(__MODULE__, :normal)

    def init(_), do: {:ok, %{}}
    def handle_call(:clear_faulty_response, _, state), do: {:reply, :ok, Map.delete(state, :error)}
    def handle_call(:set_faulty_response, _, _state), do: {:reply, :ok, %{error: true}}
    def handle_call(:set_ok_response, _, _state), do: {:reply, :ok, %{}}

    def handle_call(:get_ethereum_height, _, %{long_response: miliseconds} = state) do
      _ = Process.sleep(miliseconds)
      {:reply, {:ok, 1}, state}
    end

    def handle_call(:get_ethereum_height, _, %{error: true} = state), do: {:reply, :error, state}
    def handle_call(:get_ethereum_height, _, state), do: {:reply, {:ok, 1}, state}

    def handle_call({:set_long_response, milliseconds}, _, state),
      do: {:reply, :ok, Map.merge(%{long_response: milliseconds}, state)}

    def handle_call(:clear_long_response, _, state), do: {:reply, :ok, Map.delete(state, :long_response)}
  end

  defmodule WebSockex.ServerMock do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    match _ do
      send_resp(conn, 200, "Hello from plug")
    end

    def start(pid) when is_pid(pid) do
      ref = make_ref()
      port = Enum.random(50_000..63_000)

      url = "ws://localhost:#{port}/ws"

      opts = [dispatch: dispatch(), port: port, ref: ref]

      {:ok, _} = Plug.Adapters.Cowboy.http(__MODULE__, [], opts)
      {:ok, {ref, url}}
    end

    def start(pid, "ws://localhost:" <> <<port::bytes-size(5)>> <> "/ws" = websocket_url) when is_pid(pid) do
      ref = make_ref()

      opts = [dispatch: dispatch(), port: String.to_integer(port), ref: ref]

      {:ok, _} = Plug.Adapters.Cowboy.http(__MODULE__, [], opts)
      {:ok, {ref, websocket_url}}
    end

    def shutdown(ref) do
      Plug.Adapters.Cowboy.shutdown(ref)
    end

    defp dispatch do
      [{:_, [{"/ws", WebSockex.MockTestSocket, []}]}]
    end
  end

  defmodule WebSockex.MockTestSocket do
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

    def websocket_handle({:text, body}, req, state) do
      response = Jason.encode!(%{"params" => %{"result" => %{"number" => "0x77be11", "hash" => "0x1234"}}})
      {:reply, {:text, response}, req, state}
    end

    def websocket_info(_, req, state), do: {:ok, req, state}
  end
end
