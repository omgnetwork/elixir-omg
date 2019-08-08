use Mix.Config

config :ethereumex,
  http_options: [recv_timeout: 60_000]

config :omg_eth,
  exit_period_seconds: 10 * 60
