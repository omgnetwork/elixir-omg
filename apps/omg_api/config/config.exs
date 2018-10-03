use Mix.Config

config :omg_eth, child_block_interval: 1000
config :omg_jsonrpc, api_module: OMG.API

config :omg_api,
  ethereum_event_block_finality_margin: 10,
  ethereum_event_check_height_interval_ms: 1_000,
  rootchain_height_sync_interval_ms: 1_000,
  child_block_submit_period: 1,
  fee_specs_file_path: "./../../fee_specs.json"

import_config "#{Mix.env()}.exs"
