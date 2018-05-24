defmodule OmiseGO.Eth.DevGeth do
  @moduledoc """
  Helper module for deployment of contracts to dev geth.
  """

  @doc """
  Run geth in temp dir, kill it with SIGKILL when done.
  """

  require Logger

  def start do
    {:ok, homedir} = Briefly.create(directory: true)
    # On jenkins `geth` will be executed with regular user permissions
    # while directory is created by root. Make it writeable for `geth`.
    :ok = File.chmod(homedir, 0o777)
    res = launch("geth --dev --rpc --rpcapi=personal,eth,web3 --datadir #{homedir} 2>&1")
    {:ok, :ready} = OmiseGO.Eth.WaitFor.eth_rpc()
    res
  end

  def stop(pid) do
    # NOTE: monitor is required to stop_and_wait, wtf? monitor: true on run doesn't work
    _ = Process.monitor(pid)
    {:exit_status, 35_072} = Exexec.stop_and_wait(pid)
    :ok
  end

  # PRIVATE

  defp log_geth_output(line) do
    _ = Logger.debug(fn -> "geth: " <> line end)
    line
  end

  defp launch(cmd) do
    _ = Logger.debug(fn -> "Starting geth" end)

    {:ok, geth_proc, _ref, [{:stream, geth_out, _stream_server}]} =
      Exexec.run(cmd, stdout: :stream, kill_command: "kill -9 $(pidof geth)")

    wait_for_geth_start(geth_out)

    %Task{} = if Application.get_env(:omisego_eth, :geth_logging_in_debug) do
      fn ->
        geth_out |> Enum.each(&log_geth_output/1)
      end
      |> Task.async()
    end

    geth_proc
  end

  def wait_for_start(outstream, look_for, timeout) do
    # Monitors the stdout coming out of a process for signal of successful startup
    waiting_task_function = fn ->
      outstream
      |> Stream.map(&log_geth_output/1)
      |> Stream.take_while(fn line -> not String.contains?(line, look_for) end)
      |> Enum.to_list()
    end

    waiting_task_function
    |> Task.async()
    |> Task.await(timeout)

    :ok
  end

  defp wait_for_geth_start(geth_out) do
    wait_for_start(geth_out, "IPC endpoint opened", 15_000)
  end
end
