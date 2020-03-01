use Mix.Config

# see [here](README.md) for documentation

ethereum_client_timeout_ms = 20_000

config :ethereumex,
  url: "http://localhost:8545",
  http_options: [recv_timeout: ethereum_client_timeout_ms]

config :omg_eth,
  contract_addr: nil,
  authority_addr: nil,
  txhash_contract: nil,
  eth_node: :geth,
  child_block_interval: 1000,
  min_exit_period_seconds: nil,
  ethereum_block_time_seconds: 15,
  ethereum_events_check_interval_ms: 8_000,
  ethereum_stalled_sync_threshold_ms: 20_000,
  node_logging_in_debug: false

import_config "#{Mix.env()}.exs"
