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

defmodule OMG.Eth.SubscriptionWorkerTest do
  @moduledoc false
  alias __MODULE__.WebSockexMockTestSocket
  alias __MODULE__.WebSockexServerMock
  alias OMG.Eth.SubscriptionWorker

  use ExUnit.Case, async: false
  use OMG.Utils.LoggerExt

  @moduletag :common

  setup do
    _ = Agent.start_link(fn -> 55_600 end, name: :subscription_port_holder)
    {:ok, {server_ref, websocket_url}} = WebSockexServerMock.start()
    _ = Application.ensure_all_started(:omg_bus)
    ws_url = Application.get_env(:omg_eth, :ws_url)
    _ = Application.put_env(:omg_eth, :ws_url, websocket_url)

    on_exit(fn ->
      _ = WebSockexServerMock.shutdown(server_ref)
      _ = Application.put_env(:omg_eth, :ws_url, ws_url)
    end)

    :ok
  end

  test "that worker can subscribe to different events and receive events" do
    listen_to = ["newHeads", "newPendingTransactions"]

    Enum.each(
      listen_to,
      fn listen ->
        params = [listen_to: listen, ws_url: Application.get_env(:omg_eth, :ws_url)]
        :ok = OMG.Bus.subscribe(listen, link: true)
        _ = SubscriptionWorker.start_link([{:event_bus, OMG.Bus} | params])
        event = String.to_atom(listen)

        receive do
          {:internal_event_bus, ^event, _message} ->
            assert true
        end
      end
    )
  end

  # TODO achiurizo
  #
  # break this out into a shared module?
  # hack exvcr to read from Websocketex?
  defmodule WebSockexServerMock do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    match _ do
      send_resp(conn, 200, "Hello from plug")
    end

    def start() do
      ref = make_ref()
      port = Agent.get_and_update(:subscription_port_holder, fn state -> {state, state + 1} end)
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
          start_server(Agent.get_and_update(:subscription_port_holder, fn state -> {state, state + 1} end), ref)

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
