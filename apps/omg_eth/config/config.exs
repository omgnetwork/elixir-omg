use Mix.Config

ethereum_client_timeout_ms = 20_000

config :ethereumex,
  url: System.get_env("ETHEREUM_RPC_URL") || "http://localhost:8545",
  http_options: [recv_timeout: ethereum_client_timeout_ms]

config :omg_eth,
  contract_addr: "0xf632cfa9d5a70277f8761804d3b5e35843cd893d",
  authority_addr: "0x65f73a2ca5ec8d292e44cb41d7defbb358ebc79a",
  txhash_contract: "0xa7d0be764ce771de0133f99cda38b53ebf8255f7235d341a1c20776ddae4b920",
  # "geth" | "parity"
  eth_node: {:system, "ETH_NODE", "geth"},
  node_logging_in_debug: true,
  child_block_interval: 1000,
  exit_period_seconds: {:system, "EXIT_PERIOD_SECONDS", 7 * 24 * 60 * 60, {String, :to_integer}},
  ethereum_client_warning_time_ms: ethereum_client_timeout_ms / 4

import_config "#{Mix.env()}.exs"
