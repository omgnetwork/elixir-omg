use Mix.Config

config :omg,
  deposit_finality_margin: 10,
  ethereum_events_check_interval_ms: 500,
  coordinator_eth_height_check_interval_ms: 6_000

import_config "#{Mix.env()}.exs"
