use Mix.Config

config :logger,
  backends: [:console],
  level: :info

config :briefly,
  directory: [ "/tmp/omisego"]

import_config "#{Mix.env()}.exs"
