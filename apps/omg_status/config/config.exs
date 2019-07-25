use Mix.Config

config :omg_status,
  metrics: {:system, "METRICS", true}

config :omg_status, OMG.Status.Metric.Tracer,
  service: :omg_status,
  adapter: SpandexDatadog.Adapter,
  disabled?: {:system, "METRICS", false},
  env: {:system, "APP_ENV"},
  type: :backend

config :spandex, :decorators, tracer: OMG.Status.Metric.Tracer

config :statix,
  host: {:system, "DD_HOSTNAME", "datadog"},
  port: {:system, "DD_PORT", 8125, {String, :to_integer}}

config :spandex_datadog,
  host: {:system, "DD_HOSTNAME", "datadog"},
  port: {:system, "DD_TRACING_PORT", 8126, {String, :to_integer}},
  batch_size: {:system, "TRACING_BATCH_SIZE", 10, {String, :to_integer}},
  sync_threshold: {:system, "TRACING_SYNC_THRESHOLD", 100, {String, :to_integer}},
  http: HTTPoison

config :vmstats,
  sink: OMG.Status.Metric.VmstatsSink,
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

import_config "#{Mix.env()}.exs"
