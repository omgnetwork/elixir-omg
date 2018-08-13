defmodule OmiseGO.Performance.Runner do
  @moduledoc """
  OmiseGO performance tests - orchestration and running tests
  """

  use OmiseGO.API.LoggerExt

  @doc """
  Runs below :run function with :fprof profiler. Profiler analysis is written to the temp file.
  """
  @spec run({pos_integer(), list(), map(), boolean()}) :: {:ok, String.t()}
  def run({ntx_to_send, utxos, opts, profile}) when profile do
    opts = %{opts | profile: false}
    :fprof.apply(&OmiseGO.Performance.Runner.run/1, [{ntx_to_send, utxos, opts, opts[:profile]}], procs: [:all])
    :fprof.profile()

    destfile = Path.join(opts[:destdir], "perf_result_#{:os.system_time(:seconds)}_profiling")

    [callers: true, sort: :own, totals: true, details: true, dest: String.to_charlist(destfile)]
    |> :fprof.analyse()

    {:ok, "The :fprof output written to #{destfile}."}
  end

  @doc """
  Foreach user runs n submit_transaction requests to the chain server. Requests are done sequentially.
  """
  def run({ntx_to_send, utxos, opts, _profile}) do
    {duration, _result} =
      :timer.tc(fn ->
        # fire async transaction senders
        manager = OmiseGO.Performance.SenderManager.start_link_all_senders(ntx_to_send, utxos, opts)

        # Wait all senders do thier job, checker will stop when it happens and stops itself
        wait_for(manager)
      end)

    {:ok, "{ total_runtime_in_ms: #{round(duration / 1000)} }"}
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
