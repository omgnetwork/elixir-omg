use Mix.Config

# Target tps.
# Note that this is only a rough estimate and depends on the response time from the childchain.
# If the childchain is under high load, tps will drop.
tps = 100

# Must be >= than tps, _should_ be at least 2x tps
concurrency = 200

# Minutes that the test should run.
# Again, a rough estimate - if the childchain is under high load the test will take longer to finish
test_duration = 1

tx_delay = trunc(concurrency / tps) * 1000
tx_per_session = trunc(test_duration * 60 / trunc(tx_delay / 1000))

config :load_test,
  utxo_load_test_config: %{
    concurrent_sessions: 1,
    utxos_to_create_per_session: 30,
    transactions_per_session: 4
  },
  childchain_transactions_test_config: %{
    concurrent_sessions: concurrency,
    transactions_per_session: tx_per_session,
    transaction_delay: tx_delay
  },
  watcher_info_test_config: %{
    concurrent_sessions: 100,
    iterations: 10,
    merge_scenario_sessions: true
  },
  standard_exit_test_config: %{
    concurrent_sessions: 1,
    exits_per_session: 10
  }
