use Mix.Config

config :omisego_api,
  ethereum_event_block_finality_margin: 10,
  ethereum_event_get_deposits_interval_ms: 15_000,
  ethereum_event_max_block_range_in_deposits_query: 5

config :omisego_eth,
  child_block_interval: 1000

#import_config "#{Mix.env}.exs"
