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
  host: {:system, "DD_HOSTNAME", "datadog"},
  port: {:system, "DD_PORT", 8125, {String, :to_integer}}

config :vmstats,
  sink: OMG.OMG.Status.Metric.VmstatsSink,
  interval: 15_000,
  base_key: 'vmstats',
  key_separator: '$.',
  sched_time: true,
  memory_metrics: [
    total: :total,
    processes_used: :procs_used,
    atom_used: :atom_used,
    binary: :binary,
    ets: :ets
  ]

config :spandex_phoenix, tracer: OMG.Status.Metric.Tracer
config :spandex_ecto, SpandexEcto.EctoLogger,
  service: :ecto,
  tracer: OMG.Status.Metric.Tracer

import_config "#{Mix.env()}.exs"
