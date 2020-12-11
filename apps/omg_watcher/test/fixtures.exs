# Copyright 2019-2020 OMG Network Pte Ltd
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

  alias OMG.Status.Alert.Alarm

  deffixture in_beam_watcher(db_initialized, contract) do
    :ok = db_initialized
    _ = contract

    case System.get_env("DOCKER_GETH") do
      nil ->
        :ok

      _ ->
        # have to hack my way out of this so that we can migrate the watcher integration tests out
        Application.put_env(:omg_watcher, :exit_processor_sla_margin, 40)
    end

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
