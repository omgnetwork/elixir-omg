use Mix.Config

config :omisego_api, fee_specs_file_path: "./../../fee_specs.json"
config :omisego_eth, child_block_interval: 1000

config :omisego_api,
  ethereum_event_block_finality_margin: 10,
  ethereum_event_get_deposits_interval_ms: 5_000,
  ethereum_event_check_height_interval_ms: 1_000,
  ethereum_event_max_block_range_in_deposits_query: 5,
  child_block_submit_period: 1

import_config "#{Mix.env()}.exs"
