defmodule OmiseGO.Performance do
  @moduledoc """
  OmiseGO performance test suite module
  """

  require Logger
  import Supervisor.Spec

  @doc """
  Setup dependencies, then submits {nrequests} transcations for each of {nusers} users.
  """
  @spec setup_and_run(nrequests :: pos_integer, nusers :: pos_integer, opt :: list) :: :ok
  def setup_and_run(nrequests, nusers, opt \\ []) do
    testid = :os.system_time(:millisecond)
    {:ok, started_apps} = testup(testid)
    Logger.info "OmiseGO PerfTest ##{testid} - users: #{nusers}, reqs: #{nrequests}."

    children = [
      supervisor(Phoenix.PubSub.PG2, [:eventer, []]),
      {OmiseGO.API.State, []},
      {OmiseGO.API.FreshBlocks, []},
    ]
    Supervisor.start_link(children, [strategy: :one_for_one])

    run([testid, nrequests, nusers], opt[:profile])

    testdown(started_apps)
  end

  @doc """
  The test setup
  """
  @spec testup(testid :: integer) :: {:ok, [pid()]}
  defp testup(testid) do
    dbdir = "/tmp/perftest-#{testid}"
    Application.put_env(:omisego_db, :leveldb_path, dbdir, persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_db)

    :ok = OmiseGO.DB.multi_update([{:put, :last_deposit_block_height, 0}])

    {:ok, started_apps}
  end

  @doc """
  The test teardown
  """
  @spec testdown([pid()]) :: :ok
  defp testdown(started_apps) do
    started_apps |> Enum.reverse |> Enum.map(&Application.stop/1)
    Application.put_env(:omisego_db, :leveldb_path, nil)
  end

  @doc """
  Executes the test runner
  """
  @spec run(args :: list(), profile :: boolean) :: :ok
  defp run(args, profile) do
    {:ok, data} = apply(
                    OmiseGO.Performance.Runner,
                    (if profile, do: :profile_and_run, else: :run),
                    args)
    Logger.info data
  end
end
