use Mix.Config

config :omisego_api,
  depositor_block_finality_margin: 10,
  depositor_get_deposits_interval_ms: 60_000,
  depositor_max_block_range_in_deposits_query: 5,

  exiter_block_finality_margin: 10,
  exiter_get_deposits_interval_ms: 60_000,
  exiter_max_block_range_in_deposits_query: 5

#import_config "#{Mix.env}.exs"
