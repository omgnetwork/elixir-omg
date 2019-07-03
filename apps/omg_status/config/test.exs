use Mix.Config

config :omg_status,
       [{:metrics, false}, {:environment, :test}, {OMG.Status.Metric.Tracer, [env: "test"]}]
