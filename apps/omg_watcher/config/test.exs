use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :omg_watcher, OMG.Watcher.Web.Endpoint,
  secret_key_base: "mg2kotN5N/2c3ZtCSOzgqEcx02rp0yfKRg71GRAkBJzluMmuWIfeeaEVdKA9i/ex",
  http: [port: 7435],
  server: false

config :omg_watcher, OMG.Watcher.DB.Repo,
  ownership_timeout: 180_000,
  pool: Ecto.Adapters.SQL.Sandbox,
  # DATABASE_URL format is following `postgres://{user_name}:{password}@{host:port}/{database_name}`
  url: {:system, "DATABASE_URL", "postgres://omisego_dev:omisego_dev@localhost/omisego_test"}

config :omg_watcher,
  # NOTE: can't be made shorter. At 3 it sometimes causes :unchallenged_exit because `geth --dev` is too fast
  exit_processor_sla_margin: 5,
  block_getter_loops_interval_ms: 50,
  # NOTE: must be here - one of our integration tests actually fakes block withholding to test something
  maximum_block_withholding_time_ms: 1_000,
  exit_finality_margin: 1
