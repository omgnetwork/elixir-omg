defmodule OmiseGO.Eth.Geth do
  @moduledoc """
  Helper module for deployment of contracts to dev geth.
  """

  def start do
    # NOTE: Warnings produced here are result of Temp+Porcelain.Process being broken
    # NOTE: Dropping Temp or using Porcelain.Result instead of Process prevents warnings
    Temp.track!()
    homedir = Temp.mkdir!(%{prefix: "honted_eth_test_homedir"})
    res = launch("geth --dev --rpc --rpcapi=personal,eth,web3 --datadir #{homedir} 2>&1")
    {:ok, :ready} = OmiseGO.Eth.WaitFor.eth_rpc()
    res
  end

  def stop(pid, os_pid) do
    # NOTE: `goon` is broken, and because of that signal does not work and we do kill -9 instead
    #       Same goes for basic driver.
    Porcelain.Process.stop(pid)
    Porcelain.shell("kill -9 #{os_pid}")
  end

  # PRIVATE
  defp launch(cmd) do
    geth_pids = geth_os_pids()

    geth_proc =
      %Porcelain.Process{err: nil, out: geth_out} = Porcelain.spawn_shell(cmd, out: :stream)
    wait_for_geth_start(geth_out)

    geth_pids_after = geth_os_pids()
    [geth_os_pid] = geth_pids_after -- geth_pids
    geth_os_pid = String.trim(geth_os_pid)
    {geth_proc, geth_os_pid, geth_out}
  end

  defp geth_os_pids do
    %{out: out} = Porcelain.shell("pidof geth")

    out
    |> String.trim()
    |> String.split()
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
    wait_for_start(geth_out, "IPC endpoint opened", 3000)
  end
end
