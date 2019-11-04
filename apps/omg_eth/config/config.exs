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
  node_logging_in_debug: true,
  child_block_interval: 1000,
  min_exit_period: 7 * 24 * 60 * 60,
  ethereum_client_warning_time_ms: ethereum_client_timeout_ms / 4,
  ws_url: "ws://localhost:8546/ws",
  client_monitor_interval_ms: 10_000

import_config "#{Mix.env()}.exs"
