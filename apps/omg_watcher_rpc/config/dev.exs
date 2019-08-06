use Mix.Config

config :omg_watcher_rpc, environment: :dev
config :phoenix, :stacktrace_depth, 20

config :omg_watcher_rpc, OMG.WatcherRPC.Tracer,
  disabled?: true,
  env: "development"

config :phoenix, :plug_init_mode, :runtime
