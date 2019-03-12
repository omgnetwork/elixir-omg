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

defmodule OMG.API.EthereumClientMonitorTest do
  @moduledoc false

  use ExUnit.Case, async: true
  alias __MODULE__.Mock
  alias OMG.API.Alert.Alarm
  alias OMG.API.Alert.AlarmHandler
  alias OMG.API.EthereumClientMonitor

  setup_all do
    :ok = AlarmHandler.install()
    Mock.start_link()
    Application.put_env(:omg_api, :eth_integration_module, Mock)
    {:ok, _} = EthereumClientMonitor.start_link([])

    on_exit(fn ->
      Application.put_env(:omg_api, :eth_integration_module, nil)
    end)
  end

  setup do
    Alarm.clear_all()
  end

  test "that alarm gets raised if there's no ethereum client running" do
    Mock.set_faulty_response()
    true = is_pid(Process.whereis(EthereumClientMonitor))

    :ok =
      pull_client_alarm(400, [
        %{
          details: %{node: :erlang.node(), reporter: EthereumClientMonitor},
          id: :ethereum_client_connection
        }
      ])
  end

  test "that alarm gets raised if there's no ethereum client running and cleared when it's running" do
    Mock.set_faulty_response()
    true = is_pid(Process.whereis(EthereumClientMonitor))

    :ok =
      pull_client_alarm(400, [
        %{
          details: %{node: :erlang.node(), reporter: EthereumClientMonitor},
          id: :ethereum_client_connection
        }
      ])

    _ = Mock.set_ok_response()
    :ok = pull_client_alarm(300, [])
  end

  defp pull_client_alarm(0, _), do: {:cant_match, Alarm.all()}

  defp pull_client_alarm(n, match) do
    case Alarm.all() do
      ^match ->
        :ok

      _ ->
        Process.sleep(100)
        pull_client_alarm(n - 1, match)
    end
  end

  defmodule Mock do
    @moduledoc """
    Mocking the ETH module integration point.
    """
    use GenServer
    def start_link, do: GenServer.start_link(__MODULE__, [], name: __MODULE__)
    def get_ethereum_height, do: GenServer.call(__MODULE__, :get_ethereum_height)
    def set_faulty_response, do: GenServer.call(__MODULE__, :set_faulty_response)
    def set_ok_response, do: GenServer.call(__MODULE__, :set_ok_response)

    def init(_), do: {:ok, %{}}
    def handle_call(:set_faulty_response, _, _state), do: {:reply, :ok, :error}
    def handle_call(:set_ok_response, _, _state), do: {:reply, :ok, %{}}
    def handle_call(:get_ethereum_height, _, :error = state), do: {:reply, :error, state}
    def handle_call(:get_ethereum_height, _, state), do: {:reply, {:ok, 1}, state}
  end
end
