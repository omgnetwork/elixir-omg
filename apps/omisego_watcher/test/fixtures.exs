defmodule OmiseGOWatcher.BlockGetter.Fixtures do
  use ExUnitFixtures.FixtureModule
  require Logger

  use OmiseGO.Eth.Fixtures
  use OmiseGO.DB.Fixtures

  deffixture config_map(contract) do
    Map.merge(
      contract,
      %{
        child_block_interval: 1000,
        ethereum_event_block_finality_margin: 1,
        ethereum_event_get_deposits_interval_ms: 10
      }
    )
  end

  deffixture child_chain(config_map) do
    config_file_path = Briefly.create!(extname: ".exs")
    db_path = Briefly.create!(directory: true)

    config_file_path
    |> File.open!([:write])
    |> IO.binwrite("""
      #{OmiseGO.Eth.DevHelpers.create_conf_file(config_map)}

      config :omisego_db,
        leveldb_path: "#{db_path}"
      config :logger, level: :debug
      config :omisego_eth,
        child_block_interval: #{config_map.child_block_interval}
      config :omisego_api,
        ethereum_event_block_finality_margin: #{config_map.ethereum_event_block_finality_margin},
        ethereum_event_get_deposits_interval_ms: #{config_map.ethereum_event_get_deposits_interval_ms}
    """)
    |> File.close()

    {:ok, config} = File.read(config_file_path)
    Logger.debug(fn -> IO.ANSI.format([:blue, :bright, config], true) end)

    Logger.debug(fn -> "Starting db_init" end)

    exexec_opts_for_mix = [
      stdout: :stream,
      cd: "../..",
      env: %{"MIX_ENV" => to_string(Mix.env())}
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
        "'Application.ensure_all_started(:omisego_api); Application.ensure_all_started(:omisego_jsonrpc)' 2>&1"

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

  deffixture watcher(db_initialized) do
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
    _ = watcher
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(OmiseGOWatcher.Repo)
  end
end
