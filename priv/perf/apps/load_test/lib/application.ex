defmodule LoadTest.Application do
  @moduledoc """
  Application for the load test
  """
  use Application

  alias LoadTest.Connection.ConnectionDefaults
  alias LoadTest.Ethereum.NonceTracker
  alias LoadTest.Service.Datadog
  alias LoadTest.Service.Faucet

  def start(_type, _args) do
    :ok = start_hackney_pool()

    NonceTracker.init()

    children = [{Faucet, fetch_faucet_config()}, {Datadog, []}]

    Supervisor.start_link(children, strategy: :one_for_one, restart: :temporary)
  end

  defp start_hackney_pool() do
    pool_size = Application.fetch_env!(:load_test, :pool_size)
    max_connections = Application.fetch_env!(:load_test, :max_connection)

    :hackney_pool.start_pool(
      ConnectionDefaults.pool_name(),
      timeout: 180_000,
      connect_timeout: 30_000,
      pool_size: pool_size,
      max_connections: max_connections
    )
  end

  def stop(_app) do
    :hackney_pool.stop_pool(:perf_pool)
  end

  defp fetch_faucet_config() do
    faucet_config_keys = [
      :faucet_private_key,
      :fee_amount,
      :faucet_deposit_amount,
      :deposit_finality_margin,
      :gas_price
    ]

    Enum.map(faucet_config_keys, fn key -> {key, Application.fetch_env!(:load_test, key)} end)
  end
end
