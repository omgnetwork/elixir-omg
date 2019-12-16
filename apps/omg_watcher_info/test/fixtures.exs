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

# unfortunately something is wrong with the fixtures loading in `test_helper.exs` and the following needs to be done
Code.require_file("#{__DIR__}/../../omg_child_chain/test/omg_child_chain/integration/fixtures.exs")

defmodule OMG.WatcherInfo.Fixtures do
  use ExUnitFixtures.FixtureModule

  use OMG.Eth.Fixtures
  use OMG.DB.Fixtures
  use OMG.ChildChain.Integration.Fixtures
  use OMG.Utils.LoggerExt

  alias Ecto.Adapters.SQL
  alias FakeServer.Agents.EnvAgent
  alias FakeServer.HTTP.Server
  alias OMG.Crypto
  alias OMG.WatcherInfo
  alias OMG.WatcherInfo.DB
  alias Support.WatcherInfoHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  deffixture in_beam_watcher(db_initialized, root_chain_contract_config) do
    :ok = db_initialized
    :ok = root_chain_contract_config

    {:ok, started_apps} = Application.ensure_all_started(:omg_db)
    {:ok, started_watcher} = Application.ensure_all_started(:omg_watcher_info)
    {:ok, started_watcher_api} = Application.ensure_all_started(:omg_watcher_rpc)

    [] = DB.Repo.all(DB.Block)

    on_exit(fn ->
      Application.put_env(:omg_db, :path, nil)

      (started_apps ++ started_watcher ++ started_watcher_api)
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)
  end

  deffixture web_endpoint do
    Application.ensure_all_started(:spandex_ecto)
    Application.ensure_all_started(:telemetry)

    :telemetry.attach(
      "spandex-query-tracer",
      [:omg, :watcher, :db, :repo, :query],
      &SpandexEcto.TelemetryAdapter.handle_event/4,
      nil
    )

    {:ok, pid} = ensure_web_started(OMG.WatcherRPC.Web.Endpoint, :start_link, [], 100)

    _ = Application.load(:omg_watcher_rpc)

    on_exit(fn ->
      WatcherInfoHelper.wait_for_process(pid)
      :ok
    end)
  end

  @doc "run only database in sandbox and endpoint to make request"
  deffixture phoenix_ecto_sandbox(web_endpoint) do
    :ok = web_endpoint

    {:ok, pid} =
      Supervisor.start_link(
        [%{id: DB.Repo, start: {DB.Repo, :start_link, []}, type: :supervisor}],
        strategy: :one_for_one,
        name: WatcherInfo.Supervisor
      )

    :ok = SQL.Sandbox.checkout(DB.Repo)
    # setup and body test are performed in one process, `on_exit` is performed in another
    on_exit(fn ->
      WatcherInfoHelper.wait_for_process(pid)
      :ok
    end)
  end

  deffixture initial_blocks(alice, bob, blocks_inserter, initial_deposits) do
    :ok = initial_deposits

    [
      {1000,
       [
         OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}]),
         OMG.TestHelper.create_recovered([{1000, 0, 0, bob}], @eth, [{alice, 100}, {bob, 200}])
       ]},
      {2000,
       [
         OMG.TestHelper.create_recovered([{1000, 1, 0, alice}], @eth, [{bob, 99}, {alice, 1}], <<1337::256>>)
       ]},
      {3000,
       [
         OMG.TestHelper.create_recovered([], @eth, [{alice, 150}]),
         OMG.TestHelper.create_recovered([{1000, 1, 1, bob}], @eth, [{bob, 150}, {alice, 50}])
       ]}
    ]
    |> blocks_inserter.()
  end

  deffixture initial_deposits(alice, bob, phoenix_ecto_sandbox) do
    :ok = phoenix_ecto_sandbox

    deposits = [
      %{
        root_chain_txhash: Crypto.hash(<<1000::256>>),
        log_index: 0,
        owner: alice.addr,
        currency: @eth,
        amount: 333,
        blknum: 1
      },
      %{
        root_chain_txhash: Crypto.hash(<<2000::256>>),
        log_index: 0,
        owner: bob.addr,
        currency: @eth,
        amount: 100,
        blknum: 2
      }
    ]

    # Initial data depending tests can reuse
    DB.EthEvent.insert_deposits!(deposits)
    :ok
  end

  deffixture blocks_inserter(phoenix_ecto_sandbox) do
    :ok = phoenix_ecto_sandbox

    fn blocks -> blocks |> Enum.flat_map(&prepare_one_block/1) end
  end

  deffixture test_server do
    {:ok, server_id, port} = Server.run()
    env = FakeServer.Env.new(port)

    EnvAgent.save_env(server_id, env)

    real_addr = Application.fetch_env!(:omg_watcher_info, :child_chain_url)
    old_client_env = Application.fetch_env!(:omg_watcher_info, :child_chain_url)
    fake_addr = "http://#{env.ip}:#{env.port}"

    on_exit(fn ->
      Application.put_env(:omg_watcher_info, :child_chain_url, old_client_env)

      Server.stop(server_id)
      EnvAgent.delete_env(server_id)
    end)

    %{
      real_addr: real_addr,
      fake_addr: fake_addr,
      server_id: server_id
    }
  end

  defp prepare_one_block({blknum, recovered_txs}) do
    {:ok, _} =
      DB.Block.insert_with_transactions(%{
        transactions: recovered_txs,
        blknum: blknum,
        blkhash: "##{blknum}",
        timestamp: 1_540_465_606,
        eth_height: 1
      })

    recovered_txs
    |> Enum.with_index()
    |> Enum.map(fn {recovered_tx, txindex} -> {blknum, txindex, recovered_tx.tx_hash, recovered_tx} end)
  end

  defp ensure_web_started(module, function, args, counter) do
    _ = Process.flag(:trap_exit, true)
    do_ensure_web_started(module, function, args, counter)
  end

  defp do_ensure_web_started(module, function, args, 0), do: apply(module, function, args)

  defp do_ensure_web_started(module, function, args, counter) do
    {:ok, _pid} = result = apply(module, function, args)
    result
  rescue
    e in MatchError ->
      %MatchError{
        term:
          {:error,
           {:shutdown,
            {:failed_to_start_child, {:ranch_listener_sup, OMG.WatcherRPC.Web.Endpoint.HTTP},
             {:shutdown,
              {:failed_to_start_child, :ranch_acceptors_sup,
               {:listen_error, OMG.WatcherRPC.Web.Endpoint.HTTP, :eaddrinuse}}}}}}
      } = e

      :ok = Process.sleep(5)
      ensure_web_started(module, function, args, counter - 1)
  end
end
