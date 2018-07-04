use Mix.Config

config :omisego_eth, child_block_interval: 1000

config :logger, level: :warn

import_config "#{Mix.env()}.exs"
