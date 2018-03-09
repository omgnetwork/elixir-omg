defmodule HonteD.Integration.Geth do
  @moduledoc """
  Helper module for deployment of contracts to dev geth.
  """

  def start do
    # NOTE: Warnings produced here are result of Temp+Porcelain.Process being broken
    # NOTE: Dropping Temp or using Porcelain.Result instead of Process prevents warnings
    Temp.track!
    homedir = Temp.mkdir!(%{prefix: "honted_eth_test_homedir"})
    res = launch("geth --dev --rpc --datadir #{homedir} 2>&1")
    {:ok, :ready} = HonteD.Integration.WaitFor.eth_rpc()
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
    geth_proc = %Porcelain.Process{err: nil, out: geth_out} = Porcelain.spawn_shell(
      cmd,
      out: :stream,
    )
    geth_pids_after = geth_os_pids()
    wait_for_geth_start(geth_out)
    [geth_os_pid] = geth_pids_after -- geth_pids
    geth_os_pid = String.trim(geth_os_pid)
    {geth_proc, geth_os_pid, geth_out}
  end

  defp geth_os_pids do
    %{out: out} = Porcelain.shell("pidof geth")
    out
    |> String.trim
    |> String.split
  end

  defp wait_for_geth_start(geth_out) do
    HonteD.Integration.wait_for_start(geth_out, "IPC endpoint opened", 3000)
  end
end
