# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# By default, the umbrella project as well as each child
# application will require this configuration file, ensuring
# they all use the same configuration. While one could
# configure all applications here, we prefer to delegate
# back to each application for organization purposes.
import_config "../apps/*/config/config.exs"

# Sample configuration (overrides the imported configuration above):

config :logger, level: :info

config :logger, :console,
  format: "$date $time [$level] $metadata⋅$message⋅\n",
  discard_threshold: 2000,
  metadata: [:module, :function, :request_id]

config :logger,
  backends: [Sentry.LoggerBackend, :console]

config :sentry,
  dsn: {:system, "SENTRY_DSN"},
  enable_source_code_context: true,
  environment_name: {:system, "APP_ENV"},
  root_source_code_path: File.cwd!(),
  included_environments: [:dev, :prod, System.get_env("APP_ENV")],
  server_name: elem(:inet.gethostname(), 1),
  tags: %{
    application: System.get_env("ELIXIR_SERVICE"),
    eth_network: System.get_env("ETHEREUM_NETWORK"),
    eth_node: System.get_env("ETH_NODE")
  }

# Configs for AppSignal application monitoring
config :appsignal, :config,
  name: "OmiseGO Plasma MoreVP Implementation",
  env: Mix.env(),
  active: true

import_config "#{Mix.env()}.exs"
