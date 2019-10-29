# Copyright 2019 OmiseGO Pte Ltd
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

defmodule Support.DevParity do
  @moduledoc """
  Helper module for deployment of contracts to dev parity.
  """

  @doc """
  Run parity in temp dir, stop it with SIGHUP when done.
  """

  require Logger

  alias Support.DevMiningHelper
  alias Support.WaitFor

  def start do
    {:ok, _} = Application.ensure_all_started(:briefly)
    {:ok, _} = Application.ensure_all_started(:erlexec)
    {:ok, _} = Application.ensure_all_started(:ethereumex)
    {:ok, homedir} = Briefly.create(directory: true)

    parity_pid =
      launch(
        "parity --chain dev --geth --jsonrpc-apis personal,eth,web3,parity_accounts --ws-origins all --ws-apis eth,web3 --base-path #{
          homedir
        } 2>&1"
      )

    {:ok, :ready} = WaitFor.eth_rpc()
    {:ok, dev_period} = DevMiningHelper.start()

    on_exit = fn ->
      Process.exit(dev_period, :kill)
      stop(parity_pid)
    end

    {:ok, on_exit}
  end

  # PRIVATE

  defp stop(pid) do
    # NOTE: monitor is required to stop_and_wait, don't know why? `monitor: true` on run doesn't work
    _ = Process.monitor(pid)
    {:exit_status, 33_024} = Exexec.stop_and_wait(pid)
    :ok
  end

  defp launch(cmd) do
    _ = Logger.debug("Starting parity")

    {:ok, parity_proc, _ref, [{:stream, parity_out, _stream_server}]} =
      Exexec.run(cmd, stdout: :stream, kill_command: "pkill -HUP parity")

    wait_for_parity_start(parity_out)

    _ =
      if Application.get_env(:omg_eth, :node_logging_in_debug) do
        %Task{} =
          fn ->
            Enum.each(parity_out, &Support.DevNode.default_logger/1)
          end
          |> Task.async()
      end

    parity_proc
  end

  defp wait_for_parity_start(parity_out) do
    Support.DevNode.wait_for_start(parity_out, "Public node URL", 15_000)
  end
end
