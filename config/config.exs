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
  backends: [:console]

config :sentry,
  dsn: "url",
  environment_name: "development",
  included_environments: [:dev, :prod, "development"],
  server_name: 'localhost',
  tags: %{
    application: "development",
    eth_network: "development",
    eth_node: "geth"
  }

import_config "#{Mix.env()}.exs"
