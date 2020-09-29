use Mix.Config

config :ethereumex,
  url: "http://localhost:8545"

config :load_test,
  child_chain_url: "http://localhost:9656",
  watcher_security_url: "http://localhost:7434",
  watcher_info_url: "http://localhost:7534",
  faucet_deposit_amount: trunc(:math.pow(10, 18) * 10),
  # fee testing setup: https://github.com/omgnetwork/fee-rules-public/blob/master/fee_rules.json
  fee_amount: 75,
  utxo_load_test_config: %{
    concurrent_sessions: 10,
    utxos_to_create_per_session: 5,
    transactions_per_session: 5
  },
  childchain_transactions_test_config: %{
    concurrent_sessions: 10,
    transactions_per_session: 10
  },
  watcher_info_test_config: %{
    concurrent_sessions: 2,
    iterations: 2,
    merge_scenario_sessions: true
  },
  standard_exit_test_config: %{
    concurrent_sessions: 1,
    exits_per_session: 4
  }

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :ui, Ui.Repo,
  username: "postgres",
  password: "postgres",
  database: "ui_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ui, UiWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
