use Mix.Config

config :load_test,
  fee_wei: 30_000_000_000_000,
  #  fee_wei: 1,
  utxo_load_test_config: %{
    concurrent_sessions: 100,
    utxos_to_create_per_session: 5000,
    transactions_per_session: 100
  },
  childchain_transactions_test_config: %{
    concurrent_sessions: 1000,
    transactions_per_session: 10
  },
  watcher_info_test_config: %{
    concurrent_sessions: 100,
    iterations: 10,
    merge_scenario_sessions: true
  }
