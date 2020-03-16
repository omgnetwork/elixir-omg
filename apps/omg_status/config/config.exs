use Mix.Config

config :omg_status,
  statsd_reconnect_backoff_ms: 10_000

config :omg_status, OMG.Status.Metric.Tracer,
  service: :omg_status,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :backend

config :spandex, :decorators, tracer: OMG.Status.Metric.Tracer

config :statix,
  host: "datadog",
  port: 8125

config :spandex_datadog,
  host: "datadog",
  port: 8126,
  batch_size: 10,
  sync_threshold: 100,
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
