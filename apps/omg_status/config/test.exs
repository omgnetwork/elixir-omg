use Mix.Config

config :omg_status,
  metrics: false,
  environment: :test

config :omg_status, OMG.Status.Metric.Tracer, env: "test"
