defmodule OmiseGOWatcher.TrackerOmisego.Fixtures do
  import OmiseGO.API.TestHelper
  use ExUnitFixtures.FixtureModule
  require Logger

  defp run_process(comand, printer) do
    pid_proces =
      spawn(fn ->
        {:ok, exit_fn} = run_process(comand)

        (& &1.(&1, exit_fn, printer)).(fn continue, kill, consume ->
          receive do
            :kill_then_end_process ->
              kill.()
              send(self(), :end_proces)
              # consume last message
              continue.(continue, kill, consume)

            :end_proces ->
              nil

            msg ->
              consume.(msg)
              continue.(continue, kill, consume)
          end
        end)
      end)

    {:ok,
     fn ->
       send(pid_proces, :kill_then_end_process)
       ref = Process.monitor(pid_proces)

       receive do
         {:DOWN, ^ref, _, _, _} -> nil
       end
     end}
  end

  defp run_process(comand) do
    process_info = Port.open({:spawn, comand}, [:stream])
    info_pid = Port.info(process_info, :os_pid)

    Logger.debug(fn ->
      """
      running process:
          proces_info:\t#{inspect(process_info)}
          pid:\t#{inspect(info_pid)}
      """
    end)

    {:ok,
     fn ->
       case info_pid do
         {_, system_pid} ->
           Process.exit(process_info, :normal)
           # kill all child process of pid
           System.cmd("pkill", ["-P", Integer.to_string(system_pid)])
           # kill process
           System.cmd("kill", ["-9", Integer.to_string(system_pid)])
           Logger.debug(fn -> "kill process: #{comand}\n\tpid: #{system_pid}" end)

         _ ->
           Logger.debug(fn -> "kill process: #{comand}\n\tthe process was killed earlier" end)
       end
     end}
  end

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
      ethereum_event_block_finality_margin: 1,
      ethereum_event_get_deposit_interval_ms: 5
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
      config :omisego_eth,
        child_block_interval: #{config_map.child_block_interval}
      config :omisego_api,
        ethereum_event_block_finality_margin: #{config_map.ethereum_event_block_finality_margin},
        ethereum_event_get_deposit_interval_ms: #{config_map.ethereum_event_get_deposit_interval_ms}
    """)
    |> File.close()

    {:ok, config} = File.read(file_path)
    Logger.debug(fn -> IO.ANSI.format([:blue, :bright, config], true) end)

    {:ok, kill_process} =
      run_process("./run_child.sh #{file_path}", fn msg ->
        case msg do
          {_port, {:data, data}} ->
            Logger.debug(fn ->
              data = String.replace_suffix(List.to_string(data), "\n", "")
              IO.puts(IO.ANSI.format([:yellow, "child_chain: ", :green, :bright, data], true))
            end)

          _ ->
            nil
        end
      end)

    on_exit(fn ->
      kill_process.()
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
