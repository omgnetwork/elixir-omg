use Mix.Config

config :ethereumex,
  scheme: "http",
  host: "localhost",
  port: 8545,
  url: "http://localhost:8545",
  request_timeout: 5000

config :omg_eth,
  contract_addr: nil,
  authority_addr: nil,
  txhash_contract: nil,
  geth_logging_in_debug: true

import_config "#{Mix.env()}.exs"
