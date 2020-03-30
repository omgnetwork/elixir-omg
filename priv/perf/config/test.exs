use Mix.Config

config :ethereumex,
  url: "http://localhost:8545"

config :load_test,
  child_chain_url: "http://localhost:9656",
  watcher_security_url: "http://localhost:7434",
  watcher_info_url: "http://localhost:7534",
  faucet_deposit_wei: trunc(:math.pow(10, 18) * 10),
  initial_funds_wei: trunc(:math.pow(10, 17)),
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
  }
