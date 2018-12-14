use Mix.Config

config :ethereumex,
  url: System.get_env("ETHEREUM_RPC_URL") || "http://localhost:8545"

config :omg_eth,
  contract_addr: nil,
  authority_addr: nil,
  txhash_contract: nil,
  geth_logging_in_debug: true,
  child_block_interval: 1000

import_config "#{Mix.env()}.exs"
