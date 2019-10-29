use Mix.Config

config :omg_watcher, environment: :dev

config :omg_watcher,
  # 1 hour of Ethereum blocks
  exit_processor_sla_margin: 60 * 4

config :omg_watcher, OMG.Watcher.Tracer,
  disabled?: true,
  env: "development"
