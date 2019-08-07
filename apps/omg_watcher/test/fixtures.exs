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

defmodule OMG.Watcher.Fixtures do
  use ExUnitFixtures.FixtureModule

  use OMG.Eth.Fixtures
  use OMG.DB.Fixtures
  use OMG.ChildChain.Integration.Fixtures
  use OMG.Utils.LoggerExt

  alias Ecto.Adapters.SQL
  alias FakeServer.Agents.EnvAgent
  alias FakeServer.HTTP.Server
  alias OMG.Watcher
  alias OMG.Watcher.DB
  alias Watcher.TestHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  deffixture child_chain(contract, fee_file) do
    config_file_path = Briefly.create!(extname: ".exs")
    db_path = Briefly.create!(directory: true)

    config_file_path
    |> File.open!([:write])
    |> IO.binwrite("""
      #{OMG.Eth.DevHelpers.create_conf_file(contract)}

      config :omg_db, path: "#{db_path}"
      # this causes the inner test child chain server process to log debug. To see these logs adjust test's log level
      config :logger, level: :debug
      config :omg_child_chain, fee_specs_file_name: "#{fee_file}"
    """)
    |> File.close()

    {:ok, config} = File.read(config_file_path)
    Logger.debug(IO.ANSI.format([:blue, :bright, config], true))
    Logger.debug("Starting db_init")

    exexec_opts_for_mix = [
      stdout: :stream,
      cd: Application.fetch_env!(:omg_watcher, :umbrella_root_dir),
      env: %{"MIX_ENV" => to_string(Mix.env())},
      # group 0 will create a new process group, equal to the OS pid of that process
      group: 0,
      kill_group: true
    ]

    {:ok, _db_proc, _ref, [{:stream, db_out, _stream_server}]} =
      Exexec.run_link(
        "mix run --no-start -e ':ok = OMG.DB.init()' --config #{config_file_path} 2>&1",
        exexec_opts_for_mix
      )

    db_out |> Enum.each(&log_output("db_init", &1))

    child_chain_mix_cmd = " mix xomg.child_chain.start --config #{config_file_path} 2>&1"

    Logger.info("Starting child_chain")

    {:ok, child_chain_proc, _ref, [{:stream, child_chain_out, _stream_server}]} =
      Exexec.run_link(child_chain_mix_cmd, exexec_opts_for_mix)

    fn ->
      child_chain_out |> Enum.each(&log_output("child_chain", &1))
    end
    |> Task.async()

    on_exit(fn ->
      # NOTE see DevGeth.stop/1 for details
      _ = Process.monitor(child_chain_proc)

      :ok =
        case Exexec.stop_and_wait(child_chain_proc) do
          :normal ->
            :ok

          :shutdown ->
            :ok

          :noproc ->
            :ok

          other ->
            _ = Logger.warn("Child chain stopped with an unexpected reason")
            other
        end

      File.rm(config_file_path)
      File.rm_rf(db_path)
    end)

    :ok
  end

  defp log_output(prefix, line) do
    Logger.debug("#{prefix}: " <> line)
    line
  end

  deffixture watcher(db_initialized, root_chain_contract_config) do
    :ok = db_initialized
    :ok = root_chain_contract_config

    {:ok, started_apps} = Application.ensure_all_started(:omg_db)
    {:ok, started_watcher} = Application.ensure_all_started(:omg_watcher)
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

    {:ok, pid} =
      Supervisor.start_link(
        [
          %{id: OMG.WatcherRPC.Web.Endpoint, start: {OMG.WatcherRPC.Web.Endpoint, :start_link, []}, type: :supervisor}
        ],
        strategy: :one_for_one,
        name: Watcher.Endpoint
      )

    on_exit(fn ->
      TestHelper.wait_for_process(pid)
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
        name: Watcher.Supervisor
      )

    :ok = SQL.Sandbox.checkout(DB.Repo)
    # setup and body test are performed in one process, `on_exit` is performed in another
    on_exit(fn ->
      TestHelper.wait_for_process(pid)
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
      %{owner: alice.addr, currency: @eth, amount: 333, blknum: 1},
      %{owner: bob.addr, currency: @eth, amount: 100, blknum: 2}
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

    real_addr = Application.fetch_env!(:omg_watcher, :child_chain_url)
    old_client_env = Application.fetch_env!(:omg_watcher, :child_chain_url)
    fake_addr = "http://#{env.ip}:#{env.port}"

    on_exit(fn ->
      Application.put_env(:omg_watcher, :child_chain_url, old_client_env)

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
      DB.Transaction.update_with(%{
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
end
