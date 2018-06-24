use Mix.Config

config :ethereumex,
  request_timeout: :infinity,
  http_options: [recv_timeout: :infinity]
