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
  backends: [:console]

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: System.get_env("APP_ENV"),
  included_environments: [:dev, :prod, System.get_env("APP_ENV")],
  server_name: elem(:inet.gethostname(), 1),
  tags: %{
    application: System.get_env("ELIXIR_SERVICE"),
    eth_network: System.get_env("ETHEREUM_NETWORK"),
    eth_node: System.get_env("ETH_NODE")
  }

config :statix,
  host: System.get_env("STATSD_HOST") || "localhost",
  port: String.to_integer(System.get_env("STATSD_PORT") || "8125")

config :vmstats,
  sink: OMG.VmstatsSink,
  interval: 3000

# Configs for AppSignal application monitoring
config :appsignal, :config,
  name: "OmiseGO Plasma MoreVP Implementation",
  env: Mix.env(),
  active: true

import_config "#{Mix.env()}.exs"
