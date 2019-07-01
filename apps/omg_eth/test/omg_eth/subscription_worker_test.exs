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

defmodule OMG.Eth.SubscriptionWorkerTest do
  @moduledoc false
  alias __MODULE__.WebSockex.ServerMock
  alias OMG.Eth.SubscriptionWorker

  use ExUnitFixtures
  use ExUnit.Case, async: true

  @moduletag :wrappers
  @moduletag :common
  setup_all(_) do
    {:ok, _} =
      Supervisor.start_link(
        [
          {Phoenix.PubSub.PG2, [name: OMG.InternalEventBus]}
        ],
        strategy: :one_for_one
      )

    :ok
  end

  @tag fixtures: [:eth_node]
  test "that worker can subscribe to different events and receive events" do
    listen_to = ["newHeads", "newPendingTransactions"]

    Enum.each(
      listen_to,
      fn listen ->
        params = [listen_to: listen]
        _ = SubscriptionWorker.start_link([{:event_bus, OMG.InternalEventBus} | params])
        :ok = OMG.InternalEventBus.subscribe(listen, link: true)
        event = String.to_atom(listen)

        receive do
          {:internal_event_bus, ^event, _message} ->
            assert true
        end
      end
    )
  end

  test "that worker can subscribe to my own server via arguments" do
    {:ok, {server_ref, websocket_url}} = ServerMock.start(self())
    listen_to = ["newHeads", "newPendingTransactions"]

    Enum.each(
      listen_to,
      fn listen ->
        params = [listen_to: listen, ws_url: websocket_url]
        _ = SubscriptionWorker.start_link([{:event_bus, OMG.InternalEventBus} | params])
        :ok = OMG.InternalEventBus.subscribe(listen, link: true)
        event = String.to_atom(listen)

        receive do
          {:internal_event_bus, ^event, _message} ->
            assert true
        end
      end
    )

    ServerMock.shutdown(server_ref)
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
      port = Enum.random(60_000..63_000)

      url = "ws://localhost:#{port}/ws"

      opts = [dispatch: dispatch(), port: port, ref: ref]

      {:ok, _} = Plug.Adapters.Cowboy.http(__MODULE__, [], opts)
      {:ok, {ref, url}}
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

    def websocket_handle({:text, _body}, req, state) do
      response = Jason.encode!(%{"params" => %{"result" => %{"number" => "0x77be11", "hash" => "0x1234"}}})
      {:reply, {:text, response}, req, state}
    end

    def websocket_info(_, req, state), do: {:ok, req, state}
  end
end
