use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :omisego_watcher, OmiseGOWatcherWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :error

# Configure your database
config :omisego_watcher, OmiseGOWatcher.Repo,
  adapter: Sqlite.Ecto2,
  database: "/tmp/omisego/ecto_simple_" <> Integer.to_string(:rand.uniform(10_000_000)) <> ".sqlite3"

config :omisego_watcher, OmiseGOWatcher.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :omisego_api,
  ethereum_event_block_finality_margin: 2,
  ethereum_event_get_deposits_interval_ms: 50,
  ethereum_event_check_height_interval_ms: 50,
  ethereum_event_max_block_range_in_deposits_query: 1,
  child_block_submit_period: 1

config :omisego_eth,
  child_block_interval: 1_000

#
