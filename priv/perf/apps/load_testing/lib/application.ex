defmodule LoadTesting.Application do
  @moduledoc """
  Application for the load test
  """

  use Application

  def start(_type, _args) do
    pool_size = Application.get_env(:load_test, :pool_size)
    max_connections = Application.get_env(:load_test, :max_connection)

    :ok =
      :hackney_pool.start_pool(
        :perf_pool,
        timeout: 180_000,
        pool_size: pool_size,
        max_connections: max_connections
      )

    children = [{LoadTesting.Utils.NonceTracker, %{}}, {LoadTesting.Utils.Faucet, nil}]

    Supervisor.start_link(children, name: LoadTesting.Supervisor, strategy: :one_for_one)
  end

  def stop(_app) do
    :hackney_pool.stop_pool(:perf_pool)
  end
end
