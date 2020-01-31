use Mix.Config

config :omg_status,
  metrics: false,
  environment: :test,
  ethereum_height_check_interval_ms: 100

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

config :os_mon,
  memsup_helper_timeout: 120,
  memory_check_interval: 5,
  system_memory_high_watermark: 0.99,
  disk_almost_full_threshold: 0.99,
  disk_space_check_interval: 120
