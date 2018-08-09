defmodule OmiseGO.Performance do
  @moduledoc """
  OmiseGO performance test entrypoint. Setup and runs performance tests.

  # Examples

  ## 1 - running 3 senders each sending 5 transactions test.
  Run from terminal, from within `apps/omisego_performance`:
   > mix run --no-start -e 'OmiseGO.Performance.setup_and_run(5, 3)'

  ## 2 - running 3 senders with 5 transactions each with profiler
   > mix run --no-start -e 'OmiseGO.Performance.setup_and_run(5, 3, %{profile: true})'

  # Options

  The following options can be sent in a map as last parameters (defaults given)
  %{
    destdir: ".", # directory where the results will be put
    profile: false,
    block_every_ms: 2000 # how often do you want the tester to force a block being formed
  }
  """

  use OmiseGO.API.LoggerExt
  import Supervisor.Spec

  @doc """
  Setup dependencies, then submits {ntx_to_send} transcations for each of {nusers} users.
  """
  @spec start_simple_perf(ntx_to_send :: pos_integer, nspenders :: pos_integer, opt :: map) :: :ok
  def start_simple_perf(ntx_to_send, nspenders, opts \\ %{}) do
    _ = Logger.info(fn -> "OmiseGO PerfTest nspenders: #{inspect(spenders)}, reqs: #{inspect(ntx_to_send)}." end)

    {:ok, started_apps, api_children_supervisor} = setup_simple_pref()

    defaults = %{destdir: ".", profile: false, block_every_ms: 2000, extended_perf: true}

    opts = Map.merge(defaults, opts)

    run([ntx_to_send, create_spenders(nspenders), opts])

    cleanup_simple_pref(started_apps, api_children_supervisor)
  end

  def start_extended_perf(ntx_to_send, spenders, contract_addr, txhash_contract, opts \\ %{}) do
    _ = Logger.info(fn -> "OmiseGO PerfTest spenders: #{inspect(spenders)}, reqs: #{inspect(ntx_to_send)}." end)

#    FIXME
    defaults = %{destdir: ".", geth: "http://localhost:8545", child_chain: "http://localhost:#9656", extended_perf: false}

    opts = Map.merge(defaults, opts)

    setup_extended_pref(opts, contract_addr, txhash_contract)

    utxos = OmiseGO.Eth.DevHelpers.make_deposits(10, spenders)

    run([ntx_to_send, spenders, utxos, opts])

  end

  defp setup_extended_pref(opts, contract_addr, txhash_contract, spenders) do
    {:ok, _} = Application.ensure_all_started(:ethereumex)

    Application.put_env(:ethereumex, :request_timeout, :infinity)
    Application.put_env(:ethereumex, :http_options, [recv_timeout: :infinity])
    Application.put_env(:ethereumex, :url, opts[:geth])

    Application.put_env(:omisego_eth, :contract_addr, contract_addr)
    Application.put_env(:omisego_eth, :txhash_contract, txhash_contract)

    Application.put_env(:omisego_eth, :child_chain_url, opts[:child_chain])

  end

  @spec setup_simple_pref :: {:ok, list, pid}
  defp setup_simple_pref do
    {:ok, _} = Application.ensure_all_started(:briefly)
    {:ok, dbdir} = Briefly.create(directory: true, prefix: "leveldb")
    Application.put_env(:omisego_db, :leveldb_path, dbdir, persistent: true)
    _ = Logger.info(fn -> "Perftest leveldb path: #{inspect(dbdir)}" end)

    :ok = OmiseGO.DB.init()

    started_apps = ensure_all_started([:omisego_db, :jsonrpc2, :cowboy, :hackney])

    omisego_port = Application.get_env(:omisego_jsonrpc, :omisego_api_rpc_port)

    # select just neccessary components to run the tests
    children = [
      supervisor(Phoenix.PubSub.PG2, [:eventer, []]),
      {OmiseGO.API.State, []},
      {OmiseGO.API.FreshBlocks, []},
      {OmiseGO.API.FeeChecker, []},
      JSONRPC2.Servers.HTTP.child_spec(:http, OmiseGO.JSONRPC.Server.Handler, port: omisego_port)
    ]

    {:ok, api_children_supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

    {:ok, started_apps, api_children_supervisor}
  end

  @spec cleanup_simple_pref([], pid) :: :ok
  defp cleanup_simple_pref(started_apps, api_children_supervisor) do
    :ok = Supervisor.stop(api_children_supervisor)

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

  @spec run(args :: list()) :: :ok
  defp run(args) do
    {:ok, data} = OmiseGO.Performance.Runner.run(args)
    _ = Logger.info(fn -> "#{inspect(data)}" end)
    :ok
  end

  defp create_spenders(nspenders) do
    1..nspenders
    |> Enum.map(&OmiseGO.API.TestHelper.generate_entity)
  end

end
