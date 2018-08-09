defmodule OmiseGO.Performance.Runner do
  @moduledoc """
  OmiseGO performance tests - orchestration and running tests
  """

  use OmiseGO.API.LoggerExt

  @doc """
  Assumes test suite setup is done earlier, before running this function.
  Foreach user runs n submit_transaction requests to the chain server. Requests are done sequentially.
  """
  @spec run(ntx_to_send :: integer, nspenders :: integer, opts :: map) :: {:ok, String.t()}
  def run(ntx_to_send, spenders, opts) when !opts[:profile] do
    {duration, _result} =
      :timer.tc(fn ->
        # fire async transaction senders
        manager = OmiseGO.Performance.SenderManager.start_link_all_senders(ntx_to_send, spenders, opt)

        _ = if(opts[:block_creator]) do
          OmiseGO.Performance.BlockCreator.start_link(opt[:block_every_ms])
        end

        # Wait all senders do thier job, checker will stop when it happens and stops itself
        wait_for(manager)
      end)

    {:ok, "{ total_runtime_in_ms: #{round(duration / 1000)} }"}
  end

  @doc """
  Runs above :run function with :fprof profiler. Profiler analysis is written to the temp file.
  """
  @spec run(ntx_to_send :: pos_integer, nspenders :: pos_integer, opts :: map) :: {:ok, String.t()}
  def run(ntx_to_send, spenders, opts) when opts[:profile] do
    :fprof.apply(&OmiseGO.Performance.Runner.run/3, [ntx_to_send, spenders, opt], procs: [:all])
    :fprof.profile()

    destfile = Path.join(opt[:destdir], "perf_result_#{:os.system_time(:seconds)}_profiling")

    [callers: true, sort: :own, totals: true, details: true, dest: String.to_charlist(destfile)]
    |> :fprof.analyse()

    {:ok, "The :fprof output written to #{destfile}."}
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
