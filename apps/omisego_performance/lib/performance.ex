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
    _ = Logger.info(fn -> "OmiseGO PerfTest users: #{nusers}, reqs: #{ntx_to_send}." end)

    {:ok, started_apps} = testup()

    run([ntx_to_send, nusers, opt], opt[:profile])

    testdown(started_apps)
  end

  # The test setup
  @spec testup :: {:ok, list}
  defp testup() do
    {:ok, _} = Application.ensure_all_started(:briefly)
    {:ok, dbdir} = Briefly.create(directory: true, prefix: "leveldb")
    Application.put_env(:omisego_db, :leveldb_path, dbdir, persistent: true)
    _ = Logger.info(fn -> "Perftest leveldb path: #{dbdir}" end)

    :ok = OmiseGO.DB.init()

    started_apps = ensure_all_started([:omisego_db, :jsonrpc2, :cowboy, :hackney])

    omisego_port = Application.get_env(:omisego_jsonrpc, :omisego_api_rpc_port)

    # select just neccessary components to run the tests
    children = [
      supervisor(Phoenix.PubSub.PG2, [:eventer, []]),
      {OmiseGO.API.State, []},
      {OmiseGO.API.FreshBlocks, []},
      JSONRPC2.Servers.HTTP.child_spec(:http, OmiseGO.JSONRPC.Server.Handler, port: omisego_port)
    ]

    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)

    {:ok, started_apps}
  end

  # The test teardown
  @spec testdown([]) :: :ok
  defp testdown(started_apps) do
    started_apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    _ = Application.stop(:briefly)

    Application.put_env(:omisego_db, :leveldb_path, nil)
    :ok
  end

  # Ensures all dependent applications are started.
  # We're not basing on mix to start all neccessary test's components.
  defp ensure_all_started(app_list) do
    app_list
    |> Enum.reduce([], fn app, list ->
      {:ok, started_apps} = Application.ensure_all_started(app)
      list ++ started_apps
    end)
  end

  # Executes the test runner with (or without) profiler.
  @spec run(args :: list(), profile :: boolean) :: :ok
  defp run(args, profile) do
    {:ok, data} = apply(OmiseGO.Performance.Runner, if(profile, do: :profile_and_run, else: :run), args)
    _ = Logger.info(fn -> "#{inspect data}" end)
    :ok
  end
end
