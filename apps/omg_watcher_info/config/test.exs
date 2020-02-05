use Mix.Config

config :omg_watcher_info, child_chain_url: "http://childchain:9656"

config :omg_watcher_info, OMG.WatcherInfo.DB.Repo,
  ownership_timeout: 180_000,
  pool: Ecto.Adapters.SQL.Sandbox,
  # DATABASE_URL format is following `postgres://{user_name}:{password}@{host:port}/{database_name}`
  url: "postgres://omisego_dev:omisego_dev@postgres:5432/omisego_test"

config :omg_watcher_info,
  # NOTE: `umbrella_root_dir` fixes a common reference path to the root directory
  # of the umbrella project. This is useful because `mix test` and `mix coveralls --umbrella`
  # have different views on the root dir when testing.
  umbrella_root_dir: Path.join(__DIR__, "../../..")

config :omg_watcher_info, OMG.WatcherInfo.Tracer,
  disabled?: true,
  env: "test"

config :omg_watcher_info, environment: :test
