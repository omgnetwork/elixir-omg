use Mix.Config

config :logger, level: :warn

config :sentry,
  dsn: "url",
  environment_name: "test",
  included_environments: [],
  server_name: "test.com",
  tags: %{
    application: "test",
    eth_network: "local",
    eth_node: "geth"
  }
