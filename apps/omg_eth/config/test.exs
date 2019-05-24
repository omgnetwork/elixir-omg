use Mix.Config

# bumping these timeouts into infinity - let's rely on test timeouts rather than these
config :ethereumex,
  http_options: [recv_timeout: :infinity]

config :omg_eth,
  exit_period_seconds: 30
