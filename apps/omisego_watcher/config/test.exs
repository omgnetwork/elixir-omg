use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :omisego_watcher, OmiseGOWatcherWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :omisego_watcher, OmiseGOWatcher.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "omisego",
  password: "12345678",
  database: "test_development",
  hostname: "localhost",
  pool_size: 10

config :omisego_watcher, OmiseGOWatcher.Repo,
  pool: Ecto.Adapters.SQL.Sandbox
