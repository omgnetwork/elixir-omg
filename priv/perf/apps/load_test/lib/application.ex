defmodule LoadTest.Application do
  @moduledoc """
  Application for the load test
  """
  use Application

  def start(_type, _args) do
    {:ok, _} = Application.ensure_all_started(:telemetry)

    pool_size = Application.fetch_env!(:load_test, :pool_size)
    max_connections = Application.fetch_env!(:load_test, :max_connection)

    :ok =
      :hackney_pool.start_pool(
        LoadTest.Connection.ConnectionDefaults.pool_name(),
        timeout: 180_000,
        pool_size: pool_size,
        max_connections: max_connections
      )

    LoadTest.Ethereum.NonceTracker.init()

    faucet_config = fetch_faucet_config()
    # using temporary strategy as it creates and funds a new Ethereum account on each start
    Supervisor.start_link([{LoadTest.Service.Faucet, faucet_config}], strategy: :one_for_one, restart: :temporary)
  end

  def stop(_app) do
    :hackney_pool.stop_pool(:perf_pool)
  end

  defp fetch_faucet_config() do
    faucet_config_keys = [
      :faucet_private_key,
      :fee_wei,
      :faucet_default_funds,
      :faucet_deposit_wei,
      :deposit_finality_margin
    ]

    Enum.map(faucet_config_keys, fn key -> {key, Application.fetch_env!(:load_test, key)} end)
  end
end
