defmodule OmiseGO.Performance do
  @moduledoc """
  OmiseGO performance test entrypoint. Setup and runs performance tests.

  # Examples

  ## 1 - running 3 senders each sending 5 transactions test.
  Run from terminal:
   > mix run --no-start -e 'OmiseGO.Performance.setup_and_run(5, 3)'

  ## 2 - running 3 senders with 5 transactions each with profiler
   > mix run --no-start -e 'OmiseGO.Performance.setup_and_run(5, 3, profile: true)'

  """

  require Logger
  import Supervisor.Spec

  @doc """
  Setup dependencies, then submits {ntx_to_send} transcations for each of {nusers} users.
  """
  @spec setup_and_run(ntx_to_send :: pos_integer, nusers :: pos_integer, opt :: list) :: :ok
  def setup_and_run(ntx_to_send, nusers, opt \\ []) do
    testid = :os.system_time(:millisecond)
    {:ok, started_apps} = testup(testid)
    Logger.info("OmiseGO PerfTest ##{testid} - users: #{nusers}, reqs: #{ntx_to_send}.")

    # select just neccessary components to run the tests
    children = [
      supervisor(Phoenix.PubSub.PG2, [:eventer, []]),
      {OmiseGO.API.State, []},
      {OmiseGO.API.FreshBlocks, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)

    run([testid, ntx_to_send, nusers], opt[:profile])

    testdown(started_apps)
  end

  # The test setup
  @spec testup(testid :: integer) :: {:ok, [pid()]}
  defp testup(testid) do
    dbdir = "/tmp/perftest-#{testid}"
    Application.put_env(:omisego_db, :leveldb_path, dbdir, persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_db)

    :ok = OmiseGO.DB.multi_update([{:put, :last_deposit_block_height, 0}])
    :ok = OmiseGO.DB.multi_update([{:put, :child_top_block_number, 0}])

    {:ok, started_apps}
  end

  # The test teardown
  @spec testdown([]) :: :ok
  defp testdown(started_apps) do
    started_apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    Application.put_env(:omisego_db, :leveldb_path, nil)
    :ok
  end

  # Executes the test runner
  @spec run(args :: list(), profile :: boolean) :: :ok
  defp run(args, profile) do
    {:ok, data} = apply(OmiseGO.Performance.Runner, if(profile, do: :profile_and_run, else: :run), args)
    Logger.info(data)
    :ok
  end
end
