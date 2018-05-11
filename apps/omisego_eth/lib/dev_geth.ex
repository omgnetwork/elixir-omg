defmodule OmiseGO.Eth.DevGeth do
  @moduledoc """
  Helper module for deployment of contracts to dev geth.
  """

  def start do
    homedir = "/tmp/omisego_dev_geth_home"
    {:ok, []} = :exec.run("mkdir -p #{homedir}" |> String.to_charlist, [:sync])
    res = launch("geth --dev --rpc --rpcapi=personal,eth,web3 --datadir #{homedir} 2>&1")
    {:ok, :ready} = OmiseGO.Eth.WaitFor.eth_rpc()
    res
  end

  def stop(pid, _os_pid) do
    :exec.stop(pid)
  end

  # PRIVATE
  defp launch(cmd) do
    {:ok, helper_server, geth_out} = create_line_stream()
    {:ok, geth_proc, _} = :exec.run(String.to_charlist(cmd), stdout: helper_server)

    wait_for_geth_start(geth_out)

    {geth_proc, nil, geth_out}
  end

  defp create_line_stream do
    pid = spawn(&stdout_server_cmd/0)
    stream = Stream.unfold(pid, &get_line/1)
    {:ok, pid, stream}
  end

  defp get_line(pid) do
    ref = Process.monitor(pid)
    send(pid, {:get_line, self()})
    receive do
      {:line, line} ->
        _ = Process.demonitor(ref, [:flush])
        {line, pid}
      {'DOWN', aref, :process, _pid, :normal} when ref == aref ->
        nil
      {'DOWN', aref, :process, apid, reason} when ref == aref and pid == apid ->
        Process.exit(self(), {:unexpected_crash_of_stream_reader, reason})
    end
  end

  defp stdout_server_cmd do
    receive do
      {:get_line, caller} ->
        stdout_server_get(caller)
        stdout_server_cmd()
      :stop ->
        :normal
    end
  end

  defp stdout_server_get(caller) do
    receive do
      {:stdout, _, line} -> send(caller, {:line, line})
    end
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

  def wait_for_geth_start(geth_out) do
    wait_for_start(geth_out, "IPC endpoint opened", 15_000)
  end
end
