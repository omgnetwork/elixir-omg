use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :omg_watcher, OMG.Watcher.Web.Endpoint,
  http: [port: 4001],
  server: false

config :omg_watcher, OMG.Watcher.DB.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool: Ecto.Adapters.SQL.Sandbox,
  # DATABASE_URL format is following `postgres://{user_name}:{password}@{host:port}/{database_name}`
  url: {:system, "DATABASE_URL", "postgres://omisego_dev:omisego_dev@localhost/omisego_test"}

config :omg_watcher,
  exit_processor_sla_margin: 3,
  exit_processor_validation_interval_ms: 50,
  maximum_block_withholding_time_ms: 6_000,
  block_getter_height_sync_interval_ms: 50,
  eth_exit_finality_margin: 1
