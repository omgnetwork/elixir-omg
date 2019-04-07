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

  use ExUnit.Case, async: true
  alias __MODULE__.Mock
  alias OMG.Alert.Alarm
  alias OMG.Alert.AlarmHandler
  alias OMG.EthereumClientMonitor

  setup_all do
    :ok = AlarmHandler.install()
    Mock.start_link()
    Application.put_env(:omg_api, :eth_integration_module, Mock)
    {:ok, _} = EthereumClientMonitor.start_link([Alarm])

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
          details: %{node: Node.self(), reporter: EthereumClientMonitor},
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
          details: %{node: Node.self(), reporter: EthereumClientMonitor},
          id: :ethereum_client_connection
        }
      ])

    _ = Mock.set_ok_response()
    :ok = pull_client_alarm(300, [])
  end

  test "that we don't overflow the message queue with timers when Eth client needs time to respond" do
    Mock.set_faulty_response()
    Mock.set_long_response(4500)
    pid = Process.whereis(EthereumClientMonitor)
    true = is_pid(pid)

    _ =
      pull_client_alarm(10, [
        %{
          details: %{node: Node.self(), reporter: EthereumClientMonitor},
          id: :ethereum_client_connection
        }
      ])

    {:message_queue_len, 0} = Process.info(pid, :message_queue_len)
    _ = Mock.clear_long_response()
    :ok = pull_client_alarm(300, [])
    Mock.clear_long_response()
  rescue
    _ ->
      _ = Mock.clear_long_response()
      raise("message_queue_not_empty")
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
    def set_long_response(milliseconds), do: GenServer.call(__MODULE__, {:set_long_response, milliseconds})
    def clear_long_response, do: GenServer.call(__MODULE__, :clear_long_response)
    def set_ok_response, do: GenServer.call(__MODULE__, :set_ok_response)

    def init(_), do: {:ok, %{}}
    def handle_call(:set_faulty_response, _, _state), do: {:reply, :ok, %{error: true}}
    def handle_call(:set_ok_response, _, _state), do: {:reply, :ok, %{}}

    def handle_call(:get_ethereum_height, _, %{long_response: miliseconds} = state) do
      _ = Process.sleep(miliseconds)
      {:reply, {:ok, 1}, state}
    end

    def handle_call(:get_ethereum_height, _, %{error: true} = state), do: {:reply, :error, Map.delete(state, :error)}
    def handle_call(:get_ethereum_height, _, state), do: {:reply, {:ok, 1}, state}

    def handle_call({:set_long_response, milliseconds}, _, state),
      do: {:reply, :ok, Map.merge(%{long_response: milliseconds}, state)}

    def handle_call(:clear_long_response, _, state), do: {:reply, :ok, Map.delete(state, :long_response)}
  end
end
