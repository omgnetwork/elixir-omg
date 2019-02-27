use Mix.Config

config :omg_api,
  deposit_finality_margin: 10,
  exiters_finality_margin: 11,
  submission_finality_margin: 20,
  ethereum_events_check_interval_ms: 500,
  block_queue_eth_height_check_interval_ms: 6_000,
  coordinator_eth_height_check_interval_ms: 6_000,
  child_block_minimal_enqueue_gap: 1,
  fee_specs_file_path: "./fee_specs.json"

config :sentry,
  dsn: {:system, "SENTRY_DSN"},
  environment_name: Mix.env(),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: Mix.env(),
    application: Mix.Project.config()[:app]
  },
  server_name: elem(:inet.gethostname(), 1),
  included_environments: [:prod]

import_config "#{Mix.env()}.exs"
