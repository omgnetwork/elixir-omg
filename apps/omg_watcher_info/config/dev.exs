use Mix.Config

config :omg_watcher_info, environment: :dev

config :omg_watcher_info, OMG.WatcherInfo.Tracer,
  disabled?: true,
  env: "development"
