use Mix.Config

config :load_test,
  utxo_load_test_config: %{
    concurrent_sessions: 100,
    utxos_to_create_per_session: 5000,
    transactions_per_session: 100
  },
  childchain_transactions_test_config: %{
    concurrent_sessions: 1000,
    transactions_per_session: 10,
    transaction_delay: 0
  },
  watcher_info_test_config: %{
    concurrent_sessions: 100,
    iterations: 10,
    merge_scenario_sessions: true
  }
