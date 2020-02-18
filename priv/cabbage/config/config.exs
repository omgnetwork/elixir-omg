use Mix.Config

config :ethereumex,
  url: "http://localhost:8545",
  http_options: [timeout: 68_000, recv_timeout: 60_000]

config :tesla, adapter: Tesla.Adapter.Hackney
