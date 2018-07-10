use Mix.Config

config :logger,
  backends: [:console],
  level: :info

config :omisego_eth, geth_logging_in_debug: false
