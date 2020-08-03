import Config
ethereum_events_check_interval_ms = 8_000

config :logger, level: :info

config :logger, :console,
  format: "$date $time [$level] $metadata⋅$message⋅\n",
  discard_threshold: 2000,
  metadata: [:module, :function, :request_id, :trace_id, :span_id]

config :logger,
  backends: [Sentry.LoggerBackend, Ink]

config :logger, Ink,
  name: "elixir-omg",
  exclude_hostname: true,
  log_encoding_error: true

config :logger, Sentry.LoggerBackend,
  include_logger_metadata: true,
  ignore_plug: true

config :sentry,
  dsn: nil,
  environment_name: nil,
  included_environments: [],
  server_name: 'localhost',
  tags: %{
    application: nil,
    eth_network: nil,
    eth_node: :geth
  }

config :omg,
  deposit_finality_margin: 10,
  ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
  coordinator_eth_height_check_interval_ms: 6_000

config :omg, :eip_712_domain,
  name: "OMG Network",
  version: "1",
  salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83"

config :omg_child_chain,
  submission_finality_margin: 20,
  block_queue_eth_height_check_interval_ms: 6_000,
  block_submit_every_nth: 1,
  block_submit_max_gas_price: 20_000_000_000,
  metrics_collection_interval: 60_000,
  fee_adapter_check_interval_ms: 10_000,
  fee_buffer_duration_ms: 30_000,
  fee_adapter: {OMG.ChildChain.Fees.FileAdapter, opts: [specs_file_path: nil]}

config :omg_child_chain, OMG.ChildChain.Tracer,
  service: :omg_child_chain,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :omg_child_chain

# Configures the endpoint
# https://ninenines.eu/docs/en/cowboy/2.4/manual/cowboy_http/
# defaults are:
# protocol_options:[max_header_name_length: 64,
# max_header_value_length: 4096,
# max_headers: 100,
# max_request_line_length: 8096
# ]
config :omg_child_chain_rpc, OMG.ChildChainRPC.Web.Endpoint,
  render_errors: [view: OMG.ChildChainRPC.Web.Views.Error, accepts: ~w(json)],
  instrumenters: [SpandexPhoenix.Instrumenter],
  enable_cors: true,
  http: [:inet6, port: 9656, protocol_options: [max_request_line_length: 8192, max_header_value_length: 8192]],
  url: [host: "cc.example.com", port: 80],
  code_reloader: false

# Use Poison for JSON parsing in Phoenix
config :phoenix,
  json_library: Jason,
  serve_endpoints: true,
  persistent: true

config :omg_child_chain_rpc, OMG.ChildChainRPC.Tracer,
  service: :web,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :web

config :spandex_phoenix, tracer: OMG.ChildChainRPC.Tracer

config :omg_db,
  metrics_collection_interval: 60_000

ethereum_client_timeout_ms = 20_000

config :ethereumex,
  url: "http://localhost:8545",
  http_options: [recv_timeout: ethereum_client_timeout_ms]

config :omg_eth,
  contract_addr: nil,
  authority_address: nil,
  txhash_contract: nil,
  eth_node: :geth,
  child_block_interval: 1000,
  min_exit_period_seconds: nil,
  ethereum_block_time_seconds: 15,
  ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
  ethereum_stalled_sync_threshold_ms: 20_000,
  node_logging_in_debug: false

config :omg_status,
  statsd_reconnect_backoff_ms: 10_000,
  system_memory_check_interval_ms: 10_000,
  system_memory_high_threshold: 0.8

config :omg_status, OMG.Status.Metric.Tracer,
  service: :omg_status,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :backend

config :spandex, :decorators, tracer: OMG.Status.Metric.Tracer

config :statix,
  host: "datadog",
  port: 8125

config :spandex_datadog,
  host: "datadog",
  port: 8126,
  batch_size: 10,
  sync_threshold: 100,
  http: HTTPoison

config :vmstats,
  sink: OMG.Status.Metric.VmstatsSink,
  interval: 15_000,
  base_key: 'vmstats',
  key_separator: '$.',
  sched_time: true,
  memory_metrics: [
    total: :total,
    processes_used: :procs_used,
    atom_used: :atom_used,
    binary: :binary,
    ets: :ets
  ]

# Disable :os_mon's system_memory_high_watermark in favor of our own OMG.Status.Monitor.SystemMemory
# See http://erlang.org/pipermail/erlang-questions/2006-September/023144.html
config :os_mon,
  system_memory_high_watermark: 1.00

config :omg_watcher, child_chain_url: "http://localhost:9656"

config :omg_watcher,
  # 23 hours worth of blocks - this is how long the child chain server has to block spends from exiting utxos
  exit_processor_sla_margin: 23 * 60 * 4,
  # this means we don't want the `sla_margin` above be larger than the `min_exit_period`
  exit_processor_sla_margin_forced: false,
  maximum_block_withholding_time_ms: 15 * 60 * 60 * 1000,
  maximum_number_of_unapplied_blocks: 50,
  exit_finality_margin: 12,
  block_getter_reorg_margin: 200,
  metrics_collection_interval: 60_000

config :omg_watcher, OMG.Watcher.Tracer,
  service: :omg_watcher,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :omg_watcher

config :omg_watcher_info,
  child_chain_url: "http://localhost:9656",
  namespace: OMG.WatcherInfo,
  ecto_repos: [OMG.WatcherInfo.DB.Repo],
  metrics_collection_interval: 60_000,
  pending_block_processing_interval: 1000,
  block_queue_check_interval: 10_000

# Configures the endpoint

config :omg_watcher_info, OMG.WatcherInfo.DB.Repo,
  adapter: Ecto.Adapters.Postgres,
  # NOTE: not sure if appropriate, but this allows reasonable blocks to be written to unoptimized Postgres setup
  timeout: 180_000,
  connect_timeout: 180_000,
  url: "postgres://omisego_dev:omisego_dev@localhost/omisego_dev",
  migration_timestamps: [type: :timestamptz],
  telemetry_prefix: [:omg, :watcher_info, :db, :repo]

config :omg_watcher_info, OMG.WatcherInfo.Tracer,
  service: :ecto,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :db

# In mix environment, all modules are loaded, therefore it behaves like a watcher_info
config :omg_watcher_rpc,
  api_mode: :watcher_info

# Configures the endpoint
# https://ninenines.eu/docs/en/cowboy/2.4/manual/cowboy_http/
# defaults are:
# protocol_options:[max_header_name_length: 64,
# max_header_value_length: 4096,
# max_headers: 100,
# max_request_line_length: 8096
# ]
config :omg_watcher_rpc, OMG.WatcherRPC.Web.Endpoint,
  render_errors: [view: OMG.WatcherRPC.Web.Views.Error, accepts: ~w(json)],
  instrumenters: [SpandexPhoenix.Instrumenter],
  enable_cors: true,
  http: [:inet6, port: 7434, protocol_options: [max_request_line_length: 8192, max_header_value_length: 8192]],
  url: [host: "w.example.com", port: 80],
  code_reloader: false

config :phoenix,
  json_library: Jason,
  serve_endpoints: true,
  persistent: true

config :spandex_ecto, SpandexEcto.EctoLogger, tracer: OMG.WatcherInfo.Tracer

config :omg_watcher_rpc, OMG.WatcherRPC.Tracer,
  service: :web,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :web

config :spandex_phoenix, tracer: OMG.WatcherRPC.Tracer

config :briefly, directory: ["/tmp/omisego"]

# `watcher_url` must match respective `:omg_watcher_rpc, OMG.WatcherRPC.Web.Endpoint`
config :omg_performance, watcher_url: "localhost:7434"

import_config "#{Mix.env()}.exs"
