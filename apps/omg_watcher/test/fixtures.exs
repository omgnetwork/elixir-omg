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

defmodule OMG.Watcher.Fixtures do
  use ExUnitFixtures.FixtureModule

  use OMG.DB.Fixtures
  use OMG.Eth.Fixtures
  use OMG.Utils.LoggerExt

  alias OMG.Eth
  alias OMG.Status.Alert.Alarm
  alias OMG.TestHelper

  @payment_tx_type OMG.WireFormatTypes.tx_type_for(:tx_payment_v1)

  defp wait_for_start(outstream, look_for, timeout, logger_fn) do
    # Monitors the stdout coming out of a process for signal of successful startup
    waiting_task_function = fn ->
      outstream
      |> Stream.map(logger_fn)
      |> Stream.take_while(fn line -> not String.contains?(line, look_for) end)
      |> Enum.to_list()
    end

    waiting_task_function
    |> Task.async()
    |> Task.await(timeout)

    :ok
  end

  defp log_output(prefix, line) do
    Logger.debug("#{prefix}: " <> line)
    line
  end

  deffixture in_beam_watcher(db_initialized, contract) do
    :ok = db_initialized
    _ = contract

    {:ok, started_apps} = Application.ensure_all_started(:omg_db)
    {:ok, started_security_watcher} = Application.ensure_all_started(:omg_watcher)
    {:ok, started_watcher_api} = Application.ensure_all_started(:omg_watcher_rpc)
    wait_for_web()

    on_exit(fn ->
      Application.put_env(:omg_db, :path, nil)

      (started_apps ++ started_security_watcher ++ started_watcher_api)
      |> Enum.reverse()
      |> Enum.map(fn app ->
        :ok = Application.stop(app)
      end)

      Process.sleep(5_000)
    end)
  end

  deffixture test_server do
    server_id = :watcher_test_server
    {:ok, pid} = FakeServer.start(server_id)

    real_addr = Application.fetch_env!(:omg_watcher, :child_chain_url)
    old_client_env = Application.fetch_env!(:omg_watcher, :child_chain_url)
    {:ok, port} = FakeServer.port(server_id)
    fake_addr = "http://localhost:#{port}"

    on_exit(fn ->
      Application.put_env(:omg_watcher, :child_chain_url, old_client_env)

      FakeServer.stop(server_id)
    end)

    %{
      real_addr: real_addr,
      fake_addr: fake_addr,
      server_id: server_id,
      server_pid: pid
    }
  end

  defp wait_for_web(), do: wait_for_web(100)

  defp wait_for_web(counter) do
    case Keyword.has_key?(Alarm.all(), elem(Alarm.main_supervisor_halted(__MODULE__), 0)) do
      true ->
        Process.sleep(100)
        wait_for_web(counter - 1)

      false ->
        :ok
    end
  end
end
