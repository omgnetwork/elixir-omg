use Mix.Config

config :omisego_performance,
  fprof_analysis_dir: "./"

config :logger,
  backends: [:console],
  level: :info

#     import_config "#{Mix.env}.exs"
