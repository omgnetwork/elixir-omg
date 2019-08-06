use Mix.Config

config :omg_status,
  metrics: false,
  environment: :test,
  client_monitor_interval_ms: 10

config :omg_status, OMG.Status.Metric.Tracer,
  env: "test",
  disabled?: true

config :statix,
  host: "datadog",
  port: 8125

config :spandex_datadog,
  host: "datadog",
  port: 8126,
  batch_size: 10,
  sync_threshold: 10,
  http: HTTPoison
