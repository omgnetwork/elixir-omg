use Mix.Config

config :ethereumex,
  url: "http://localhost:8545",
  http_options: [timeout: 500_000, recv_timeout: 500_000]

config :cabbage,
  reorg: System.get_env("REORG")

config :tesla, adapter: Tesla.Adapter.Hackney

config :logger, level: :info
