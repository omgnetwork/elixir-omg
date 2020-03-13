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
  metadata: [:module, :function, :request_id, :trace_id, :span_id]

config :logger,
  backends: [Sentry.LoggerBackend, Ink]

config :logger, Ink,
  name: "elixir-omg",
  exclude_hostname: true

config :logger, Sentry.LoggerBackend,
  include_logger_metadata: true,
  ignore_plug: true

config :sentry,
  dsn: nil,
  environment_name: nil,
  included_environments: [],
  server_name: 'localhost',
  tags: %{
    application: nil,
    eth_network: nil,
    eth_node: :geth
  }

import_config "#{Mix.env()}.exs"
