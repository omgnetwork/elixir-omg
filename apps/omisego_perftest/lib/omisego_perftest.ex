defmodule OmiseGO.PerfTest.Runner do
  @moduledoc """
  OmiseGO performance tests - orchestration and running tests
  """

  require Logger

  @doc """
  Assumes test suite setup is done earlier, before running this function.
  Foreach user runs n submit_transaction requests to the chain server. Requests are done sequencially.
  """
  @spec run(testid :: integer, nrequests :: integer, nusers :: integer) :: :ok
  def run(testid, nrequests, nusers) do
    start = :os.system_time(:millisecond)

    # init proces registry
    {:ok, _} = Registry.start_link(keys: :duplicate, name: OmiseGO.PerfTest.Registry)

    # fire async transaction senders
    #TODO: Consider running senders in supervisor - but would they restore their state?
    1..nusers |> Enum.map(fn senderid -> OmiseGO.PerfTest.SenderServer.start_link({senderid, nrequests}) end)

    # Wait all senders do thier job, checker will stop when it happens and stops itself
    wait_for(OmiseGO.PerfTest.Registry)
    stop = :os.system_time(:millisecond)

    {:ok, "{ total_runtime_in_ms: #{stop-start}, testid: #{testid} }"}
  end

  @doc """
  Runs above :run function with :fprof profiler. Profiler analysis is written to the temp file.
  """
  @spec profile_and_run(testid :: integer, nrequests :: pos_integer, nusers :: pos_integer) :: :ok
  def profile_and_run(testid, nrequests, nusers) do
    :fprof.apply(&OmiseGO.PerfTest.Runner.run/3, [testid, nrequests, nusers], [procs: [:all]])
    :fprof.profile()

    destfile = "/tmp/perftest-tx#{nrequests}-u#{nusers}-#{testid}.analysis"
    [   callers: true,
        sort: :own,
        totals: true,
        details: true,
        dest: String.to_charlist(destfile),]
    |> :fprof.analyse()
    |> IO.puts

    {:ok, "The :fprof output written to #{destfile}."}
  end

  @doc """
  Waits until all sender processes ends sending Tx and deregister themselves from the registry
  """
  @spec wait_for(registry :: pid() | atom()) :: :ok
  defp wait_for(registry) do
    ref = Process.monitor(OmiseGO.PerfTest.WaitFor.start(registry))
    receive do
      {:DOWN, ^ref, :process, _obj, reason} ->
        Logger.info "Stoping performance tests, reason: #{reason}"
    end
  end
end
