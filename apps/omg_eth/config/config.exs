use Mix.Config

ethereum_client_timeout_ms = 20_000

config :ethereumex,
  url: System.get_env("ETHEREUM_RPC_URL") || "http://localhost:8545",
  http_options: [recv_timeout: ethereum_client_timeout_ms]

config :omg_eth,
  contract_addr: "0x070744423f0cb7edd8998e60db0c3c6c86844e03",
  txhash_contract: "0x4b1af5a565932d6a84c63933adf12ae52d72aec2ea20095d4b534a40b6d1a919",
  authority_addr: "0x1a7beb447983c6e1fd1a72a082517ef09d85c212",
  geth_logging_in_debug: true,
  child_block_interval: 1000,
  exit_period_seconds: {:system, "EXIT_PERIOD_SECONDS", 7 * 24 * 60 * 60, {String, :to_integer}},
  ethereum_client_warning_time_ms: ethereum_client_timeout_ms / 4

import_config "#{Mix.env()}.exs"
