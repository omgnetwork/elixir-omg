use Mix.Config
config :omg_child_chain_rpc, environment: :dev
config :phoenix, :stacktrace_depth, 20

config :omg_child_chain_rpc, OMG.ChildChainRPC.Tracer,
  disabled?: true,
  env: "development"

config :phoenix, :plug_init_mode, :runtime
