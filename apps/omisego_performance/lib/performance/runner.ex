defmodule OmiseGO.Performance.Runner do
  @moduledoc """
  OmiseGO performance tests - orchestration and running tests
  """

  require Logger

  @doc """
  Assumes test suite setup is done earlier, before running this function.
  Foreach user runs n submit_transaction requests to the chain server. Requests are done sequentially.
  """
  @spec run(testid :: integer, ntx_to_send :: integer, nusers :: integer) :: {:ok, String.t()}
  def run(testid, ntx_to_send, nusers) do
    Application.put_env(:omisego_performance, :test_env, {testid, ntx_to_send, nusers})
    start = System.monotonic_time(:millisecond)

    # fire async transaction senders
    manager = OmiseGO.Performance.SenderManager.start(ntx_to_send, nusers)

    # fire block creator
    _ = OmiseGO.Performance.BlockCreator.start_link()

    # Wait all senders do thier job, checker will stop when it happens and stops itself
    wait_for(manager)
    stop = System.monotonic_time(:millisecond)

    {:ok, "{ total_runtime_in_ms: #{stop - start}, testid: #{testid} }"}
  end

  @doc """
  Runs above :run function with :fprof profiler. Profiler analysis is written to the temp file.
  """
  @spec profile_and_run(testid :: integer, ntx_to_send :: pos_integer, nusers :: pos_integer) :: {:ok, String.t()}
  def profile_and_run(testid, ntx_to_send, nusers) do
    :fprof.apply(&OmiseGO.Performance.Runner.run/3, [testid, ntx_to_send, nusers], procs: [:all])
    :fprof.profile()

    destdir = Application.get_env(:omisego_performance, :analysis_output_dir)
    destfile = "#{destdir}/perftest-tx#{ntx_to_send}-u#{nusers}-#{testid}.analysis"

    [callers: true, sort: :own, totals: true, details: true, dest: String.to_charlist(destfile)]
    |> :fprof.analyse()

    {:ok, "The :fprof output written to #{destfile}."}
  end

  @spec get_test_env() :: tuple()
  def get_test_env do
    Application.get_env(:omisego_performance, :test_env)
  end

  # Waits until all sender processes ends sending Tx and deregister themselves from the registry
  @spec wait_for(registry :: pid() | atom()) :: :ok
  defp wait_for(registry) do
    ref = Process.monitor(registry)

    receive do
      {:DOWN, ^ref, :process, _obj, reason} ->
        Logger.info("Stoping performance tests, reason: #{reason}")
    end
  end
end
