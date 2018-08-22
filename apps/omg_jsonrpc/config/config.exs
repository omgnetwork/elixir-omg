use Mix.Config

config :omg_jsonrpc,
  omg_api_rpc_port: 9656,
  child_chain_url: "http://localhost:9656"

import_config "#{Mix.env()}.exs"
