use Mix.Config

config :logger,
  level: :debug

config :omisego_jsonrpc,
  omisego_api_rpc_port: 9656,
  child_chain_url: "http://localhost"

import_config "#{Mix.env()}.exs"
