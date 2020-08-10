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

defmodule OMG.Performance.Runner do
  @moduledoc """
  Orchestration and running tests
  """

  use OMG.Utils.LoggerExt

  @doc """
  Kicks off the sending of the transactions, with or without profiling depending on the `profile` arg

  Foreach user runs n submit_transaction requests to the chain server. Requests are done sequentially for every user
  """
  @spec run(pos_integer(), list(), keyword(), profile :: boolean()) :: :ok
  def run(ntx_to_send, utxos, opts, true), do: do_profiled_run(ntx_to_send, utxos, opts)
  def run(ntx_to_send, utxos, opts, false), do: do_run(ntx_to_send, utxos, opts)

  defp do_run(ntx_to_send, utxos, opts) do
    {duration, _result} =
      :timer.tc(fn ->
        # fire async transaction senders
        manager = OMG.Performance.SenderManager.start_link_all_senders(ntx_to_send, utxos, opts)

        # Wait all senders do their job, checker will stop when it happens and stops itself
        wait_for(manager)
      end)

    _ = Logger.info("{ total_runtime_in_ms: #{inspect(round(duration / 1000))} }")

    :ok
  end

  defp do_profiled_run(ntx_to_send, utxos, opts) do
    :fprof.apply(&do_run/3, [ntx_to_send, utxos, opts], procs: [:all])
    :fprof.profile()

    destfile = Path.join(opts[:destdir], "perf_result_profiling_#{:os.system_time(:seconds)}")

    [callers: true, sort: :own, totals: true, details: true, dest: String.to_charlist(destfile)]
    |> :fprof.analyse()

    _ = Logger.info("The :fprof output written to #{inspect(destfile)}.")

    :ok
  end

  # Waits until all sender processes ends sending Tx and deregister themselves from the registry
  @spec wait_for(registry :: pid() | atom()) :: :ok
  defp wait_for(registry) do
    ref = Process.monitor(registry)

    receive do
      {:DOWN, ^ref, :process, _obj, reason} ->
        Logger.info("Stoping performance tests, reason: #{inspect(reason)}")
    end
  end
end
