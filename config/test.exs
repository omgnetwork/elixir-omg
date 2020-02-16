use Mix.Config

config :logger, level: :debug

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
