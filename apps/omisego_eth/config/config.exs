use Mix.Config

config :ethereumex,
  scheme: "http",
  host: "localhost",
  port: 8545,
  url: "http://localhost:8545",
  request_timeout: 5000

config :omisego_eth,
  contract: "0x0",
  authority_addr: "0x0",
  txhash_contract: "0x0",
  geth_logging_in_debug: true

import_config "#{Mix.env()}.exs"
