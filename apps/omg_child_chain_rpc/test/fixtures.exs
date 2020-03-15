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

defmodule OMG.ChildChainRPC.Fixtures do
  use ExUnitFixtures.FixtureModule

  @doc "run only endpoint to make request"
  deffixture phoenix_sandbox do
    :ok = Enum.each([:sasl, :os_mon, :omg_status], fn app -> Application.stop(app) end)
    {:ok, apps} = Application.ensure_all_started(:omg_status)
    {:ok, apps2} = Application.ensure_all_started(:plug_cowboy)
    {:ok, pid} = OMG.ChildChainRPC.Application.start([], [])
    _ = Application.load(:omg_child_chain_rpc)

    on_exit(fn ->
      (apps ++ apps2) |> Enum.reverse() |> Enum.each(&Application.stop(&1))

      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, _, _} ->
          # a tiny wait to allow the endpoint to be brought down for good, not sure how to get rid of the sleep
          # without it one might get `eaddrinuse`
          Process.sleep(10)
          :ok
      end
    end)
  end
end
