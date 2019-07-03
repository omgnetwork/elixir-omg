use Mix.Config

config :omg_status,
       [
         {OMG.Status.Metric.Tracer,
          [
            service: :omg_status,
            adapter: SpandexDatadog.Adapter,
            env: {:system, "APP_ENV"}
          ]},
         {:metrics, true}
       ]

import_config "#{Mix.env()}.exs"
