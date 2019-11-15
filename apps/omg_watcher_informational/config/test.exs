use Mix.Config

config :omg_watcher_informational, child_chain_url: "http://localhost:9656"

config :omg_watcher_informational, OMG.WatcherInformational.DB.Repo,
  ownership_timeout: 180_000,
  pool: Ecto.Adapters.SQL.Sandbox,
  # DATABASE_URL format is following `postgres://{user_name}:{password}@{host:port}/{database_name}`
  url: "postgres://omisego_dev:omisego_dev@localhost:5432/omisego_test"

config :omg_watcher_informational, OMG.WatcherInformational.Tracer,
  disabled?: true,
  env: "test"

config :omg_watcher_informational, environment: :test
