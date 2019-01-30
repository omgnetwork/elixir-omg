use Mix.Config

# bumping because otherwise import/unlock of accounts will fail in some of use cases (perf tests)
config :ethereumex,
  http_options: [recv_timeout: 60_000]
