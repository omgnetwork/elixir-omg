use Mix.Config

config :logger,
  backends: [:console, Sentry.LoggerBackend]
