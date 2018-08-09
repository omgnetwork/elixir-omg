use Mix.Config

config :ethereumex,
  url: "http://localhost:8545",
  request_timeout: 5000

config :omisego_eth,
  contract_addr: nil,
  authority_addr: nil,
  txhash_contract: nil,
  geth_logging_in_debug: true

import_config "#{Mix.env()}.exs"
