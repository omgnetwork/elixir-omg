use Mix.Config

# see [here](README.md) for documentation

ethereum_client_timeout_ms = 20_000

config :ethereumex,
  url: System.get_env("ETHEREUM_RPC_URL") || "http://localhost:8545",
  http_options: [recv_timeout: ethereum_client_timeout_ms]

config :omg_eth,
  contract_addr: nil,
  authority_addr: nil,
  txhash_contract: nil,
  # "geth" | "parity"
  eth_node: {:system, "ETH_NODE", "geth"},
  node_logging_in_debug: true,
  child_block_interval: 1000,
  exit_period_seconds: {:system, "EXIT_PERIOD_SECONDS", 7 * 24 * 60 * 60, {String, :to_integer}},
  ethereum_client_warning_time_ms: ethereum_client_timeout_ms / 4,
  ws_url: System.get_env("ETHEREUM_WS_RPC_URL") || "ws://localhost:8546/ws"

config :omg_eth, OMG.Utils.Tracer,
  service: :omg_eth,
  adapter: SpandexDatadog.Adapter,
  disabled?: false,
  env: Atom.to_string(Mix.env())

import_config "#{Mix.env()}.exs"
