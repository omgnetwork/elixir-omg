use Mix.Config

config :omg_status,
  metrics: false,
  environment: :test,
  client_monitor_interval_ms: 10

config :omg_status, OMG.Status.Metric.Tracer,
  service: :omg_status,
  env: "test",
  disabled?: true

# we don't want system alarms auto raised
config :os_mon,
  memsup_helper_timeout: 120,
  memory_check_interval: 5,
  system_memory_high_watermark: 0.99,
  disk_almost_full_threshold: 0.99,
  disk_space_check_interval: 120
