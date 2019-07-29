use Mix.Config

config :omg_status,
  metrics: false,
  environment: :test,
  client_monitor_interval_ms: 10

config :omg_status, OMG.Status.Metric.Tracer, env: "test"
