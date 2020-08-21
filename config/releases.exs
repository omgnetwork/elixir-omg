import Config

# This `releases.exs` config file gets evaluated at RUNTIME, unlike other config files that are
# evaluated at compile-time.
#
# See https://hexdocs.pm/mix/1.9.0/Mix.Tasks.Release.html#module-runtime-configuration

config :omg_child_chain,
  block_submit_max_gas_price: String.to_integer(System.get_env("BLOCK_SUBMIT_MAX_GAS_PRICE") || "20000000000"),
  block_submit_gas_price_strategy:
    case System.get_env("BLOCK_SUBMIT_GAS_PRICE_STRATEGY") do
      "POISSON" -> OMG.ChildChain.GasPrice.Strategy.PoissonGasStrategy
      "BLOCK_PERCENTILE" -> OMG.ChildChain.GasPrice.Strategy.BlockPercentileGasStrategy
      "LEGACY" -> OMG.ChildChain.GasPrice.Strategy.LegacyGasStrategy
      nil -> OMG.ChildChain.GasPrice.Strategy.LegacyGasStrategy
      invalid -> raise("Invalid gas strategy. Got: #{invalid}")
    end

config :omg_watcher_info, OMG.WatcherInfo.DB.Repo,
  # Have at most `:pool_size` DB connections on standby and serving DB queries.
  pool_size: String.to_integer(System.get_env("WATCHER_INFO_DB_POOL_SIZE") || "10"),
  # Wait at most `:queue_target` for a connection. If all connections checked out during
  # a `:queue_interval` takes more than `:queue_target`, then we double the `:queue_target`.
  # If checking out connections take longer than the new target, a DBConnection.ConnectionError is raised.
  # See: https://hexdocs.pm/db_connection/DBConnection.html#start_link/2-queue-config
  queue_target: String.to_integer(System.get_env("WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS") || "50"),
  queue_interval: String.to_integer(System.get_env("WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS") || "1000")
