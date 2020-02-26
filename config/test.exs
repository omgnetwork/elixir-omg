use Mix.Config

config :logger, level: :warn

config :logger,
  backends: [:console, Sentry.LoggerBackend]

config :sentry,
  dsn: nil,
  environment_name: nil,
  included_environments: [],
  server_name: nil,
  tags: %{
    application: nil,
    eth_network: nil,
    eth_node: :geth
  }
