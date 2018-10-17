# Copyright 2018 OmiseGO Pte Ltd
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
Code.require_file("#{__DIR__}/../../omg_api/test/integration/fixtures.exs")

defmodule OMG.Watcher.Fixtures do
  use ExUnitFixtures.FixtureModule

  use OMG.Eth.Fixtures
  use OMG.DB.Fixtures
  use OMG.API.Integration.Fixtures
  use OMG.API.LoggerExt
  alias OMG.Watcher.TestHelper

  deffixture child_chain(contract, fee_file) do
    config_file_path = Briefly.create!(extname: ".exs")
    db_path = Briefly.create!(directory: true)

    config_file_path
    |> File.open!([:write])
    |> IO.binwrite("""
      #{OMG.Eth.DevHelpers.create_conf_file(contract)}

      config :omg_db,
        leveldb_path: "#{db_path}"
      config :logger, level: :debug
      config :omg_eth,
        child_block_interval: #{Application.get_env(:omg_eth, :child_block_interval)}
      config :omg_api,
        fee_specs_file_path: "#{fee_file}",
        rootchain_height_sync_interval_ms: #{Application.get_env(:omg_api, :rootchain_height_sync_interval_ms)},
        ethereum_event_block_finality_margin: #{Application.get_env(:omg_api, :ethereum_event_block_finality_margin)},
        ethereum_event_check_height_interval_ms: #{
      Application.get_env(:omg_api, :ethereum_event_check_height_interval_ms)
    }
    """)
    |> File.close()

    {:ok, config} = File.read(config_file_path)
    Logger.debug(fn -> IO.ANSI.format([:blue, :bright, config], true) end)
    Logger.debug(fn -> "Starting db_init" end)

    exexec_opts_for_mix = [
      stdout: :stream,
      cd: "../..",
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

    child_chain_mix_cmd =
      "mix run --no-start --no-halt --config #{config_file_path} -e " <>
        "'{:ok, _} = Application.ensure_all_started(:omg_api)' " <> "2>&1"

    Logger.debug(fn -> "Starting child_chain" end)

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
            _ = Logger.warn(fn -> "Child chain stopped with an unexpected reason" end)
            other
        end

      File.rm(config_file_path)
      File.rm_rf(db_path)
    end)

    :ok
  end

  defp log_output(prefix, line) do
    Logger.debug(fn -> "#{prefix}: " <> line end)
    line
  end

  deffixture watcher(db_initialized, root_chain_contract_config) do
    :ok = root_chain_contract_config
    :ok = db_initialized
    {:ok, started_apps} = Application.ensure_all_started(:omg_db)
    {:ok, started_watcher} = Application.ensure_all_started(:omg_watcher)

    on_exit(fn ->
      Application.put_env(:omg_db, :leveldb_path, nil)

      (started_apps ++ started_watcher)
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)
  end

  deffixture watcher_sandbox(watcher) do
    :ok = watcher
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(OMG.Watcher.DB.Repo, ownership_timeout: 90_000)
    Ecto.Adapters.SQL.Sandbox.mode(OMG.Watcher.DB.Repo, {:shared, self()})
  end

  @doc "run only database in sandbox and endpoint to make request"
  deffixture phoenix_ecto_sandbox do
    import Supervisor.Spec

    {:ok, pid} =
      Supervisor.start_link(
        [supervisor(OMG.Watcher.DB.Repo, []), supervisor(OMG.Watcher.Web.Endpoint, [])],
        strategy: :one_for_one,
        name: OMG.Watcher.Supervisor
      )

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(OMG.Watcher.DB.Repo)
    # setup and body test are performed in one process, `on_exit` is performed in another
    on_exit(fn ->
      TestHelper.wait_for_process(pid)
      :ok
    end)
  end

  deffixture initial_blocks(entities, phoenix_ecto_sandbox) do
    alias OMG.Watcher.DB
    eth = OMG.API.Crypto.zero_address()

    %{alice: alice, bob: bob} = entities
    :ok = phoenix_ecto_sandbox

    prepare_f = fn {blknum, recovered_txs} ->
      {:ok, _} = DB.Transaction.update_with(%{transactions: recovered_txs, blknum: blknum, eth_height: 1})

      recovered_txs
      |> Enum.with_index()
      |> Enum.map(fn {recovered_tx, txindex} -> {blknum, txindex, recovered_tx.signed_tx_hash, recovered_tx} end)
    end

    # Initial data depending tests can reuse
    OMG.Watcher.DB.EthEvent.insert_deposits([
      %{owner: alice.addr, currency: eth, amount: 333, blknum: 1},
      %{owner: bob.addr, currency: eth, amount: 100, blknum: 2}
    ])

    [
      {1000,
       [
         OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], eth, [{bob, 300}]),
         OMG.API.TestHelper.create_recovered([{1000, 0, 0, bob}], eth, [{alice, 100}, {bob, 200}])
       ]},
      {2000, [OMG.API.TestHelper.create_recovered([{1000, 1, 0, alice}], eth, [{bob, 99}, {alice, 1}])]},
      {3000,
       [
         OMG.API.TestHelper.create_recovered([], eth, [{alice, 150}]),
         OMG.API.TestHelper.create_recovered([{1000, 1, 1, bob}], eth, [{bob, 150}, {alice, 50}])
       ]}
    ]
    |> Enum.flat_map(prepare_f)
  end
end
