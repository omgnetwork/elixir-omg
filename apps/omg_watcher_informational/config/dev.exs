use Mix.Config

config :omg_watcher_informational, environment: :dev

config :omg_watcher_informational, OMG.WatcherInformational.Tracer,
  disabled?: true,
  env: "development"
