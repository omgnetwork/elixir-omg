import Config

# This `releases.exs` config file gets evaluated at RUNTIME, unlike other config files that are
# evaluated at compile-time.
#
# See https://hexdocs.pm/mix/1.9.0/Mix.Tasks.Release.html#module-runtime-configuration

config :omg_watcher_info, OMG.WatcherInfo.DB.Repo,
  # Have at most `:pool_size` DB connections on standby and serving DB queries.
  pool_size: String.to_integer(System.get_env("WATCHER_INFO_DB_POOL_SIZE") || "10"),
  # Wait at most `:queue_target` for a connection. If all connections checked out during
  # a `:queue_interval` takes more than `:queue_target`, then we double the `:queue_target`.
  # If checking out connections take longer than the new target, a DBConnection.ConnectionError is raised.
  # See: https://hexdocs.pm/db_connection/DBConnection.html#start_link/2-queue-config
  queue_target: String.to_integer(System.get_env("WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS") || "50"),
  queue_interval: String.to_integer(System.get_env("WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS") || "1000"),
