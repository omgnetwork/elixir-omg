use Mix.Config

config :omg_watcher, child_chain_url: "http://localhost:9656"

config :omg_watcher, OMG.Watcher.DB.Repo,
  ownership_timeout: 180_000,
  pool: Ecto.Adapters.SQL.Sandbox,
  # DATABASE_URL format is following `postgres://{user_name}:{password}@{host:port}/{database_name}`
  url: "postgres://omisego_dev:omisego_dev@localhost/omisego_test"

config :omg_watcher,
  # NOTE: can't be made shorter. At 3 it sometimes causes :unchallenged_exit because `geth --dev` is too fast
  exit_processor_sla_margin: 5,
  block_getter_loops_interval_ms: 50,
  # NOTE: must be here - one of our integration tests actually fakes block withholding to test something
  maximum_block_withholding_time_ms: 1_000,
  exit_finality_margin: 1,
  # an entry to fix a common reference path to the root directory of the umbrella project
  # this is useful because `mix test` and `mix coveralls --umbrella` have different views on the root dir when testing
  umbrella_root_dir: Path.join(__DIR__, "../../..")

config :omg_watcher, OMG.Watcher.Tracer,
  disabled?: true,
  env: "test"

config :omg_watcher, environment: :test
