use Mix.Config

config :omg_child_chain, OMG.ChildChain.Tracer,
  service: :omg_child_chain,
  adapter: SpandexDatadog.Adapter,
  disabled?: false,
  env: "PROD"
