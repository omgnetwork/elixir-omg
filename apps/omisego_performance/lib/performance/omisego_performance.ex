defmodule OmiseGO.Performance.Runner do
  @moduledoc """
  OmiseGO performance tests - orchestration and running tests
  """

  require Logger

  @doc """
  Assumes test suite setup is done earlier, before running this function.
  Foreach user runs n submit_transaction requests to the chain server. Requests are done sequentially.
  """
  @spec run(testid :: integer, ntx_to_send :: integer, nusers :: integer) :: :ok
  def run(testid, ntx_to_send, nusers) do
    start = :os.system_time(:millisecond)

    # init proces registry
    {:ok, _} = Registry.start_link(keys: :duplicate, name: OmiseGO.Performance.Registry)

    # fire async transaction senders
    1..nusers |> Enum.map(fn senderid -> OmiseGO.Performance.SenderServer.start_link({senderid, ntx_to_send}) end)

    # Wait all senders do thier job, checker will stop when it happens and stops itself
    wait_for(OmiseGO.Performance.Registry)
    stop = :os.system_time(:millisecond)

    {:ok, "{ total_runtime_in_ms: #{stop-start}, testid: #{testid} }"}
  end

  @doc """
  Runs above :run function with :fprof profiler. Profiler analysis is written to the temp file.
  """
  @spec profile_and_run(testid :: integer, ntx_to_send :: pos_integer, nusers :: pos_integer) :: :ok
  def profile_and_run(testid, ntx_to_send, nusers) do
    :fprof.apply(&OmiseGO.Performance.Runner.run/3, [testid, ntx_to_send, nusers], [procs: [:all]])
    :fprof.profile()

    destdir = Application.get_env(:omisego_performance, :fprof_analysis_dir)
    destfile = "#{destdir}/perftest-tx#{ntx_to_send}-u#{nusers}-#{testid}.analysis"
    [   callers: true,
        sort: :own,
        totals: true,
        details: true,
        dest: String.to_charlist(destfile),]
    |> :fprof.analyse()

    {:ok, "The :fprof output written to #{destfile}."}
  end

  @doc """
  Waits until all sender processes ends sending Tx and deregister themselves from the registry
  """
  @spec wait_for(registry :: pid() | atom()) :: :ok
  defp wait_for(registry) do
    ref = Process.monitor(OmiseGO.Performance.WaitFor.start(registry))
    receive do
      {:DOWN, ^ref, :process, _obj, reason} ->
        Logger.info "Stoping performance tests, reason: #{reason}"
    end
  end
end
