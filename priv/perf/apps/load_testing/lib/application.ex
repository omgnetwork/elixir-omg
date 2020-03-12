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

    children = [{LoadTesting.Server.NonceTracker, []}, {LoadTesting.Server.Faucet, faucet_opts()}]

    Supervisor.start_link(children, name: LoadTesting.Supervisor, strategy: :one_for_one)
  end

  def stop(_app) do
    :hackney_pool.stop_pool(:perf_pool)
  end

  defp faucet_opts() do
    faucet_opt =
      case Application.fetch_env(:load_testing, :faucet_account) do
        {:ok, %{priv: priv}} ->
          faucet_account = priv |> ExPlasma.Encoding.to_binary() |> LoadTesting.Utils.Account.new()
          [faucet: faucet_account]

        :error ->
          []
      end

    [:fee_wei, :faucet_default_funds, :faucet_deposit_wei, :deposit_finality_margin]
    |> Enum.reduce([], fn key, acc ->
      [{key, Application.fetch_env!(:load_testing, key)} | acc]
    end)
    |> Keyword.merge(faucet_opt)
  end
end
