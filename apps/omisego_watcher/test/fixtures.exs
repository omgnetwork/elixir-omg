defmodule OmiseGOWatcher.TrackerOmisego.Fixtures do
  import OmiseGO.API.TestHelper
  use ExUnitFixtures.FixtureModule
  require Logger

  deffixture geth do
    {:ok, exit_fn} = OmiseGO.Eth.dev_geth()
    on_exit(exit_fn)
    :ok
  end

  deffixture contract(geth) do
    _ = geth
    {:ok, contract_address, txhash, authority} = OmiseGO.Eth.DevHelpers.prepare_env("../../")
    # TODO think about another solution
    Application.put_env(:omisego_watcher, OmiseGOWatcher.TrackerOmisego, %{
      contract_address: contract_address
    })

    %{
      address: contract_address,
      from: authority,
      txhash: txhash
    }
  end

  deffixture config_map(contract) do
    %{
      contract: contract,
      child_block_interval: 1000,
      ethereum_event_block_finality_margin: 2,
      ethereum_event_get_deposit_interval_ms: 10
    }
  end

  deffixture child_chain(config_map) do
    test_sid = Integer.to_string(:rand.uniform(10_000_000))
    file_path = "/tmp/omisego/config_" <> test_sid <> ".exs"
    db_path = "/tmp/omisego/db_" <> test_sid

    file_path
    |> File.open!([:write])
    |> IO.binwrite("""
      #{
      OmiseGO.Eth.DevHelpers.create_conf_file(
        config_map.contract.address,
        config_map.contract.txhash,
        config_map.contract.from
      )
    }
      config :omisego_db,
        leveldb_path: "#{db_path}"
      config :logger, level: :debug
      config :omisego_eth,
        child_block_interval: #{config_map.child_block_interval}
      config :omisego_api,
        ethereum_event_block_finality_margin: #{config_map.ethereum_event_block_finality_margin},
        ethereum_event_get_deposit_interval_ms: #{config_map.ethereum_event_get_deposit_interval_ms}
    """)
    |> File.close()

    {:ok, config} = File.read(file_path)
    Logger.debug(fn -> IO.ANSI.format([:blue, :bright, config], true) end)

    {:ok, _db_proc, _ref, [{:stream, db_out, _stream_server}]} =
      Exexec.run_link(
        "mix run --no-start -e 'OmiseGO.DB.init()' --config #{file_path} 2>&1",
        stdout: :stream,
        cd: "../.."
      )

    db_out
    |> Enum.each(fn line -> Logger.debug(fn -> "db_init: " <> line end) end)

    # TODO I wish we could ensure_started just one app here, but in test env jsonrpc doesn't depend on api :(
    child_chain_mix_cmd =
      "mix run --no-start --no-halt --config #{file_path} -e " <>
        "'Application.ensure_all_started(:omisego_api); Application.ensure_all_started(:omisego_jsonrpc)' 2>&1"

    {:ok, child_chain_proc, _ref, [{:stream, child_chain_out, _stream_server}]} =
      Exexec.run(
        child_chain_mix_cmd,
        stdout: :stream,
        kill_timeout: 0,
        cd: "../.."
      )

    fn ->
      child_chain_out
      |> Enum.each(fn line -> Logger.debug(fn -> "child_chain: " <> line end) end)
    end
    |> Task.async()

    on_exit(fn ->
      # NOTE see DevGeth.stop/1 for details
      _ = Process.monitor(child_chain_proc)
      :normal = Exexec.stop_and_wait(child_chain_proc)

      File.rm(file_path)
      File.rm_rf(db_path)
    end)

    :ok
  end

  deffixture(alice, do: generate_entity())
  deffixture(bob, do: generate_entity())

  deffixture db_init do
    test_sid = Integer.to_string(:rand.uniform(10_000_000))
    dir = "/tmp/omisego/db_" <> test_sid
    File.mkdir_p!(dir)

    Application.put_env(:omisego_db, :leveldb_path, dir, persistent: true)
    OmiseGO.DB.init()
  end

  deffixture watcher(db_init) do
    _ = db_init
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
