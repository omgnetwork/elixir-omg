use Mix.Config

config :omg_api,
  deposit_finality_margin: 10,
  exiters_finality_margin: 11,
  submission_finality_margin: 20,
  ethereum_status_check_interval_ms: 500,
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
