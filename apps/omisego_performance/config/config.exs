use Mix.Config

config :omisego_performance,
  analysis_output_dir: "./",
  jsonrpc_api_address: "localhost:4000/"

config :logger,
  backends: [:console],
  level: :info
