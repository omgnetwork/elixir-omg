use Mix.Config

config :omg_api,
  deposit_finality_margin: 10,
  exiters_finality_margin: 11,
  submission_finality_margin: 20,
  ethereum_events_check_interval_ms: 500,
  block_queue_eth_height_check_interval_ms: 6_000,
  coordinator_eth_height_check_interval_ms: 6_000,
  child_block_minimal_enqueue_gap: 1,
  fee_specs_file_path: "./fee_specs.json"

import_config "#{Mix.env()}.exs"
