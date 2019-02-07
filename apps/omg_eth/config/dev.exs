use Mix.Config

# bumping because otherwise import/unlock of accounts will fail in some of use cases (perf tests)
config :ethereumex,
  http_options: [recv_timeout: 60_000]

config :omg_eth,
  exit_period_seconds: {:system, "EXIT_PERIOD_SECONDS", 4 * 60, {String, :to_integer}}
