use Mix.Config

config :omg_watcher, environment: :dev

config :omg_watcher, OMG.Watcher.Tracer,
  disabled?: false,
  env: "development"
