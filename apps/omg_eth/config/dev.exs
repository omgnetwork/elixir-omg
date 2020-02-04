use Mix.Config

config :ethereumex,
  http_options: [recv_timeout: 60_000]

config :omg_eth,
  min_exit_period_seconds: 10 * 60,
  node_logging_in_debug: true
