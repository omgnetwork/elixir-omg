defmodule OmiseGOWatcher.TrackerOmisego.Fixtures do
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

    Logger.debug("""
    running process:
        proces_info:\t#{inspect(process_info)}
        pid:\t#{inspect(info_pid)}
    """)

    {:ok,
     fn ->
       case info_pid do
         {_, system_pid} ->
           Process.exit(process_info, :normal)
           # kill all child process of pid
           System.cmd("pkill", ["-P", Integer.to_string(system_pid)])
           # kill process
           System.cmd("kill", ["-9", Integer.to_string(system_pid)])
           Logger.debug("kill process: #{comand}\n\tpid: #{system_pid}")

         _ ->
           Logger.debug("kill process: #{comand}\n\tthe process was killed earlier")
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
    #TODO think about another solution
    Application.put_env(:omisego_watcher, OmiseGOWatcher.TrackerOmisego, %{
      contract_address: contract_address})
    %{
      address: contract_address,
      from: authority,
      txhash: txhash
    }
  end

  deffixture child_chain(contract) do
    file_path = "/tmp/config_" <> Integer.to_string(:rand.uniform(10_000_000)) <> ".exs"

    file_path
    |> File.open!([:write])
    |> IO.binwrite(
      OmiseGO.Eth.DevHelpers.create_conf_file(contract.address, contract.txhash, contract.from) <>
        "\n" <> String.replace( ("../omisego_api/config/config.exs" |> File.read() |> elem(1)) ,"use Mix.Config","")
    )
    |> File.close()

    {:ok, config} = File.read(file_path)
    Logger.debug(IO.ANSI.format([:blue, :bright, config], true))

    {:ok, kill_process} =
      run_process("./run_child.sh #{file_path}", fn msg ->
        case msg do
          {_port, {:data, data}} ->
            data = String.replace_suffix(List.to_string(data), "\n", "")

            IO.puts(IO.ANSI.format([:yellow, "child_chain: ", :green, :bright, data], true))

          _ ->
            nil
        end
      end)

    on_exit(fn ->
      kill_process.()
      File.rm(file_path)
    end)

    :ok
  end
end
