defmodule OmiseGO.Eth.DevGeth do
  @moduledoc """
  Helper module for deployment of contracts to dev geth.
  """

  @doc """
  Run geth in temp dir, kill it with SIGKILL when done.
  """
  def start do
    {:ok, homedir} = Briefly.create(directory: true)
    :ok = File.chmod(homedir, 0o777)
    res = launch("geth --dev --rpc --rpcapi=personal,eth,web3 --datadir #{homedir} 2>&1")
    {:ok, :ready} = OmiseGO.Eth.WaitFor.eth_rpc()
    res
  end

  def stop(pid) do
    ref = Process.monitor(pid)
    :ok = Exexec.stop(pid)
    receive do
      {:"DOWN", aref, _process, _pid, _reason} when aref == ref -> :ok
    end
  end

  # PRIVATE

  defp launch(cmd) do
    {:ok, geth_proc, _ref, [{:stream, geth_out, stream_server}]} =
      Exexec.run(cmd, stdout: :stream, kill_command: "kill -9 $(pidof geth)")
    wait_for_geth_start(geth_out)
    geth_proc
  end

  def wait_for_start(outstream, look_for, timeout) do
    # Monitors the stdout coming out of a process for signal of successful startup
    waiting_task_function = fn ->
      outstream
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
