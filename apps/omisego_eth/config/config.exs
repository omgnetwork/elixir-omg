use Mix.Config

config :ethereumex,
  scheme: "http",
  host: "localhost",
  port: 8545,
  url: "http://localhost:8545",
  request_timeout: 5000

import_config "#{Mix.env()}.exs"
