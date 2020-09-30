# Copyright 2019-2020 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Eth.DevGeth do
  @moduledoc """
  Helper module for deployment of contracts to dev geth.
  """

  @doc """
  Run geth in temp dir, kill it with SIGKILL when done.
  """

  require Logger

  alias Support.WaitFor

  def start() do
    {:ok, homedir} = Briefly.create(directory: true)
    snapshot_dir = Path.expand(Path.join([Mix.Project.build_path(), "../../", "data/geth/"]))
    {"", 0} = System.cmd("cp", ["-rf", snapshot_dir, homedir])

    keystore = Path.join([homedir, "/geth/keystore"])
    datadir = Path.join([homedir, "/geth"])
    :ok = File.write!("/tmp/geth-blank-password", "")
    geth = ~s(geth --miner.gastarget 7500000 \
            --nodiscover \
            --maxpeers 0 \
            --miner.gasprice "10" \
            --syncmode 'full' \
            --networkid 1337 \
            --gasprice '1' \
            --keystore #{keystore} \
            --password /tmp/geth-blank-password \
            --unlock "0,1" \
            --rpc --rpcapi personal,web3,eth,net --rpcaddr 0.0.0.0 --rpcvhosts='*' --rpcport=8545 \
            --ws --wsaddr 0.0.0.0 --wsorigins='*' \
            --allow-insecure-unlock \
            --mine --datadir #{datadir} 2>&1)
    geth_pid = launch(geth)

    {:ok, :ready} = WaitFor.eth_rpc(20_000)

    on_exit = fn -> stop(geth_pid) end

    {:ok, on_exit}
  end

  # PRIVATE

  defp stop(pid) do
    # NOTE: monitor is required to stop_and_wait, don't know why? `monitor: true` on run doesn't work
    _ = Process.monitor(pid)

    {:exit_status, 35_072} = Exexec.stop_and_wait(pid)
    :ok
  end

  defp launch(cmd) do
    _ = Logger.debug("Starting geth")

    {:ok, geth_proc, os_proc} = Exexec.run(cmd, stdout: true, kill_command: "pkill -9 geth")

    wait_for_geth_start(os_proc)

    geth_proc
  end

  defp wait_for_geth_start(ps_os_pid, count \\ 15) do
    receive do
      {:stdout, ^ps_os_pid, stdout} ->
        cond do
          String.contains?(stdout, "IPC endpoint opened") ->
            :ok

          count > 0 ->
            Process.sleep(1_000)
            wait_for_geth_start(ps_os_pid, count - 1)

          true ->
            :error
        end
    after
      30_000 -> :error
    end
  end
end
