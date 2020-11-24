import Config

# This `releases.exs` config file gets evaluated at RUNTIME, unlike other config files that are
# evaluated at compile-time.
#
# See https://hexdocs.pm/mix/1.9.0/Mix.Tasks.Release.html#module-runtime-configuration

# with this helper anon. function you can
# load and validate specific watcher or watcher info
# configuration
# env_var_name - gets passed into System.get_env/1
# exception - is the string that gets thrown so that we prevent release boot
# third argument is if this is a watcher info resolver
# fourth argument is whether this is a watcher info specific configuration
mandatory = fn
  env_var_name, exception, true, true ->
    case System.get_env(env_var_name) do
      nil -> throw(exception)
      data -> data
    end

  env_var_name, _, _, _ ->
    "WATCHER_INFO config #{env_var_name} in WATCHER SECURITY"
end

watcher_info? = fn -> Code.ensure_loaded?(OMG.WatcherInfo) end

config :omg_watcher_info, OMG.WatcherInfo.DB.Repo,
  url: mandatory.("DATABASE_URL", "DATABASE_URL needs to be set.", watcher_info?.(), true),
  # Have at most `:pool_size` DB connections on standby and serving DB queries.
  pool_size: String.to_integer(System.get_env("WATCHER_INFO_DB_POOL_SIZE") || "10"),
  # Wait at most `:queue_target` for a connection. If all connections checked out during
  # a `:queue_interval` takes more than `:queue_target`, then we double the `:queue_target`.
  # If checking out connections take longer than the new target, a DBConnection.ConnectionError is raised.
  # See: https://hexdocs.pm/db_connection/DBConnection.html#start_link/2-queue-config
  queue_target: String.to_integer(System.get_env("WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS") || "50"),
  queue_interval: String.to_integer(System.get_env("WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS") || "1000")
