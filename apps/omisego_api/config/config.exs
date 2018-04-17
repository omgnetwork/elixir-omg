use Mix.Config

config :omisego_api,
  ethereum_event_block_finality_margin: 10,
  ethereum_event_get_deposits_interval_ms: 60_000,
  ethereum_event_max_block_range_in_deposits_query: 5

#import_config "#{Mix.env}.exs"
