defmodule LoadTest.Application do
  @moduledoc """
  Application for the load test
  """
  use Application

  alias ExPlasma.Encoding
  alias LoadTest.Ethereum.Account

  def start(_type, _args) do
    pool_size = Application.fetch_env!(:load_test, :pool_size)
    max_connections = Application.fetch_env!(:load_test, :max_connection)

    :ok =
      :hackney_pool.start_pool(
        :perf_pool,
        timeout: 180_000,
        pool_size: pool_size,
        max_connections: max_connections
      )

    :ok = start_services()

    {:ok, self()}
  end

  def stop(_app) do
    :hackney_pool.stop_pool(:perf_pool)
  end

  defp start_services() do
    {:ok, _} =
      Supervisor.start_link([{LoadTest.Service.NonceTracker, []}], name: LoadTest.Supervisor, strategy: :one_for_one)

    faucet_config = fetch_faucet_config()
    # not started under supervisor as it creates and funds a new Ethereum account on each start
    {:ok, _} = LoadTest.Service.Faucet.start_link(faucet_config)
    :ok
  end

  defp fetch_faucet_config() do
    faucet_opt =
      case Application.fetch_env(:load_test, :faucet_account) do
        {:ok, %{priv: priv}} ->
          {:ok, faucet_account} = priv |> Encoding.to_binary() |> Account.new()
          [faucet: faucet_account]

        :error ->
          []
      end

    [:fee_wei, :faucet_default_funds, :faucet_deposit_wei, :deposit_finality_margin]
    |> Enum.reduce([], fn key, acc -> [{key, Application.fetch_env!(:load_test, key)} | acc] end)
    |> Keyword.merge(faucet_opt)
  end
end
