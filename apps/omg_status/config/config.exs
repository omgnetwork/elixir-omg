use Mix.Config

config :omg_status,
  metrics: true

import_config "#{Mix.env()}.exs"
