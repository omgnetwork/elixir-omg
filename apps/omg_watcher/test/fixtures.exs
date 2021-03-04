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

  alias OMG.Eth.Configuration
  alias OMG.Status.Alert.Alarm
  alias OMG.Watcher.State.Core

  import OMG.Watcher.TestHelper

  @eth <<0::160>>
  @fee_claimer_address "NO FEE CLAIMER ADDR!"

  deffixture(entities, do: entities())

  deffixture(alice(entities), do: entities.alice)
  deffixture(bob(entities), do: entities.bob)
  deffixture(carol(entities), do: entities.carol)

  deffixture(stable_alice(entities), do: entities.stable_alice)
  deffixture(stable_bob(entities), do: entities.stable_bob)
  deffixture(stable_mallory(entities), do: entities.stable_mallory)

  deffixture state_empty() do
    child_block_interval = Configuration.child_block_interval()
    {:ok, state} = Core.extract_initial_state(0, child_block_interval, @fee_claimer_address)
    state
  end

  deffixture state_alice_deposit(state_empty, alice) do
    do_deposit(state_empty, alice, %{amount: 10, currency: @eth, blknum: 1})
  end

  deffixture state_stable_alice_deposit(state_empty, stable_alice) do
    do_deposit(state_empty, stable_alice, %{amount: 10, currency: @eth, blknum: 1})
  end

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
