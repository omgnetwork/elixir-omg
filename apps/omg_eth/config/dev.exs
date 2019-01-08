use Mix.Config

# bumping because otherwise import/unlock of accounts will fail in some of use cases (perf tests)
config :ethereumex,
  request_timeout: 60_000,
  loggers: [Appsignal.Ecto, Ecto.LogEntry]
