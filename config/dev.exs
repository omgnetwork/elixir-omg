import Config

config :logger,
  backends: [:console, Sentry.LoggerBackend]

config :omg,
  ethereum_events_check_interval_ms: 500,
  coordinator_eth_height_check_interval_ms: 1_000

config :omg_db,
  path: Path.join([System.get_env("HOME"), ".omg/data"])

config :ethereumex,
  http_options: [recv_timeout: 60_000]

config :omg_eth,
  min_exit_period_seconds: 10 * 60,
  ethereum_block_time_seconds: 1,
  node_logging_in_debug: true

config :omg_watcher_rpc, environment: :dev
config :phoenix, :stacktrace_depth, 20

config :omg_watcher_rpc, OMG.WatcherRPC.Tracer,
  disabled?: true,
  env: "development"

config :omg_watcher_info, environment: :dev

config :omg_watcher_info, OMG.WatcherInfo.Tracer,
  disabled?: true,
  env: "development"

config :omg_watcher, environment: :dev

config :omg_watcher,
  # 1 hour of Ethereum blocks
  exit_processor_sla_margin: 60 * 4,
  # this means we allow the `sla_margin` above be larger than the `min_exit_period`
  exit_processor_sla_margin_forced: true

config :omg_watcher, OMG.Watcher.Tracer,
  disabled?: true,
  env: "development"

config :omg_status, OMG.Status.Metric.Tracer,
  env: "development",
  disabled?: true
