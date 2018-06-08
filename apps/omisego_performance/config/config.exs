use Mix.Config

config :omisego_performance, analysis_output_dir: "./"

config :logger,
  backends: [:console],
  level: :info

import_config "#{Mix.env()}.exs"
