defmodule OmiseGOWatcher.BlockGetter.Fixtures do
  use ExUnitFixtures.FixtureModule

  use OmiseGO.Eth.Fixtures
  use OmiseGO.DB.Fixtures
  use OmiseGO.API.LoggerExt
  alias OmiseGOWatcher.TestHelper

  deffixture child_chain(contract, token) do
    config_file_path = Briefly.create!(extname: ".exs")
    db_path = Briefly.create!(directory: true)

    {:ok, eth} = OmiseGO.API.Crypto.encode_address(OmiseGO.API.Crypto.zero_address())
    fees = %{eth => 0, token.address => 0}
    {:ok, fees_path} = OmiseGO.API.TestHelper.write_fee_file(fees)

    config_file_path
    |> File.open!([:write])
    |> IO.binwrite("""
      #{OmiseGO.Eth.DevHelpers.create_conf_file(contract)}

      config :omisego_db,
        leveldb_path: "#{db_path}"
      config :logger, level: :debug
      config :omisego_eth,
        child_block_interval: #{Application.get_env(:omisego_eth, :child_block_interval)}
      config :omisego_api,
        fee_specs_file_path: "#{fees_path}",
        ethereum_event_block_finality_margin: #{
      Application.get_env(:omisego_api, :ethereum_event_block_finality_margin)
    },
        ethereum_event_get_deposits_interval_ms: #{
      Application.get_env(:omisego_api, :ethereum_event_get_deposits_interval_ms)
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
        "mix run --no-start -e ':ok = OmiseGO.DB.init()' --config #{config_file_path} 2>&1",
        exexec_opts_for_mix
      )

    db_out |> Enum.each(&log_output("db_init", &1))

    # TODO I wish we could ensure_started just one app here, but in test env jsonrpc doesn't depend on api :(
    child_chain_mix_cmd =
      "mix run --no-start --no-halt --config #{config_file_path} -e " <>
        "'{:ok, _} = Application.ensure_all_started(:omisego_api);" <>
        " {:ok, _} = Application.ensure_all_started(:omisego_jsonrpc)' " <> "2>&1"

    Logger.debug(fn -> "Starting child_chain" end)

    {:ok, child_chain_proc, _ref, [{:stream, child_chain_out, _stream_server}]} =
      Exexec.run(child_chain_mix_cmd, exexec_opts_for_mix)

    fn ->
      child_chain_out |> Enum.each(&log_output("child_chain", &1))
    end
    |> Task.async()

    on_exit(fn ->
      # NOTE see DevGeth.stop/1 for details
      _ = Process.monitor(child_chain_proc)
      :normal = Exexec.stop_and_wait(child_chain_proc)

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
    {:ok, started_apps} = Application.ensure_all_started(:omisego_db)
    {:ok, started_watcher} = Application.ensure_all_started(:omisego_watcher)

    on_exit(fn ->
      Application.put_env(:omisego_db, :leveldb_path, nil)

      (started_apps ++ started_watcher)
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)
  end

  deffixture watcher_sandbox(watcher) do
    :ok = watcher
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(OmiseGOWatcher.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(OmiseGOWatcher.Repo, {:shared, self()})
  end

  @doc "run only database in sandbox and endpoint to make request"
  deffixture phoenix_ecto_sandbox do
    import Supervisor.Spec

    {:ok, pid} =
      Supervisor.start_link(
        [supervisor(OmiseGOWatcher.Repo, []), supervisor(OmiseGOWatcherWeb.Endpoint, [])],
        strategy: :one_for_one,
        name: OmiseGOWatcher.Supervisor
      )

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(OmiseGOWatcher.Repo)
    # setup and body test are performed in one process, `on_exit` is performed in another
    on_exit(fn ->
      TestHelper.wait_for_process(pid)
      :ok
    end)
  end
end
