use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :omg_watcher, OMG.Watcher.Web.Endpoint,
  http: [port: 4001],
  server: false

config :omg_watcher, OMG.Watcher.DB.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool: Ecto.Adapters.SQL.Sandbox,
  url: {:system, "DATABASE_URL", "postgres://omisego_dev:omisego_dev@localhost/omisego_test"}

config :omg_watcher, block_getter_height_sync_interval_ms: 1_000

config :omg_api,
  ethereum_event_block_finality_margin: 2,
  ethereum_event_check_height_interval_ms: 50,
  child_block_submit_period: 1,
  rootchain_height_sync_interval_ms: 1_000

config :omg_eth, child_block_interval: 1_000
