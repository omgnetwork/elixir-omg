use Mix.Config

config :omg_eth, child_block_interval: 1000

config :omg_api,
  eth_deposit_finality_margin: 10,
  eth_submission_finality_margin: 20,
  ethereum_event_check_height_interval_ms: 1_000,
  rootchain_height_sync_interval_ms: 1_000,
  child_block_minimal_enquque_gap: 4,
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
  included_environments: [:prod, :dev]

import_config "#{Mix.env()}.exs"
