use Mix.Config

config :logger,
  backends: [:console],
  level: :info

import_config "#{Mix.env()}.exs"
