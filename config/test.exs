use Mix.Config

parse_contracts = fn ->
  local_umbrella_path = Path.join([File.cwd!(), "../../", "localchain_contract_addresses.env"])

  contract_addreses_path =
    case File.exists?(local_umbrella_path) do
      true ->
        local_umbrella_path

      _ ->
        # CI/CD
        Path.join([File.cwd!(), "localchain_contract_addresses.env"])
    end

  contract_addreses_path
  |> File.read!()
  |> String.split("\n", trim: true)
  |> List.flatten()
  |> Enum.reduce(%{}, fn line, acc ->
    [key, value] = String.split(line, "=")
    Map.put(acc, key, value)
  end)
end

contracts = parse_contracts.()

config :logger, level: :warn

config :logger,
  backends: [:console, Sentry.LoggerBackend]

config :sentry,
  dsn: nil,
  environment_name: nil,
  included_environments: [],
  server_name: nil,
  tags: %{
    application: nil,
    eth_network: nil,
    eth_node: :geth
  }

config :omg_utils,
  environment: :test

config :omg,
  deposit_finality_margin: 1,
  ethereum_events_check_interval_ms: 10,
  coordinator_eth_height_check_interval_ms: 10,
  environment: :test,
  fee_claimer_address: Base.decode16!("DEAD000000000000000000000000000000000000")

config :omg_child_chain,
  block_queue_eth_height_check_interval_ms: 100,
  fee_adapter_check_interval_ms: 1_000,
  fee_buffer_duration_ms: 5_000,
  fee_adapter:
    {OMG.ChildChain.Fees.FileAdapter,
     opts: [
       specs_file_path: Path.join(__DIR__, "../apps/omg_child_chain/test/omg_child_chain/support/fee_specs.json")
     ]}

# We need to start OMG.ChildChainRPC.Web.Endpoint with HTTP server for Performance and Watcher tests to work
# as a drawback lightweight (without HTTP server) controller tests are no longer an option.
config :omg_child_chain_rpc, OMG.ChildChainRPC.Web.Endpoint,
  http: [port: 9657],
  server: true

config :omg_child_chain_rpc, OMG.ChildChainRPC.Tracer,
  disabled?: true,
  env: "test"

config :omg_child_chain_rpc, environment: :test

# config :omg_db,
#  path: Path.join([System.get_env("HOME"), ".omg/data"])

# bumping these timeouts into infinity - let's rely on test timeouts rather than these
config :ethereumex,
  url: "http://localhost:8545",
  http_options: [recv_timeout: :infinity],
  id_reset: true

config :omg_eth,
  # Needed for test only to have some value of address when `:contract_address` is not set explicitly
  # required by the EIP-712 struct hash code
  txhash_contract: contracts["TXHASH_CONTRACT"],
  authority_address: contracts["AUTHORITY_ADDRESS"],
  contract_addr: %{
    erc20_vault: contracts["CONTRACT_ADDRESS_ERC20_VAULT"],
    eth_vault: contracts["CONTRACT_ADDRESS_ETH_VAULT"],
    payment_exit_game: contracts["CONTRACT_ADDRESS_PAYMENT_EXIT_GAME"],
    plasma_framework: contracts["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"]
  },
  node_logging_in_debug: true

config :omg_eth,
  # Lower the event check interval too low and geth will die
  ethereum_events_check_interval_ms: 400,
  min_exit_period_seconds: 22,
  ethereum_block_time_seconds: 1,
  eth_node: :geth,
  run_test_eth_dev_node: true

config :omg_performance, watcher_url: "localhost:7435"

config :omg_status,
  metrics: false,
  environment: :test,
  statsd_reconnect_backoff_ms: 10

config :omg_status, OMG.Status.Metric.Tracer,
  env: "test",
  disabled?: true

config :statix,
  host: "datadog",
  port: 8125

config :spandex_datadog,
  host: "datadog",
  port: 8126,
  batch_size: 10,
  sync_threshold: 10,
  http: HTTPoison

config :os_mon,
  memsup_helper_timeout: 120,
  memory_check_interval: 5,
  system_memory_high_watermark: 0.99,
  disk_almost_full_threshold: 0.99,
  disk_space_check_interval: 120

config :omg_watcher, child_chain_url: "http://localhost:9657"

config :omg_watcher,
  block_getter_loops_interval_ms: 50,
  # NOTE `exit_processor_sla_margin` can't be made shorter. At 3 it sometimes
  # causes :unchallenged_exit because `geth --dev` is too fast
  exit_processor_sla_margin: 5,
  # this means we allow the `sla_margin` above be larger than the `min_exit_period`
  exit_processor_sla_margin_forced: true,
  # NOTE: `maximum_block_withholding_time_ms` must be here - one of our integration tests
  # actually fakes block withholding to test something
  maximum_block_withholding_time_ms: 1_000,
  exit_finality_margin: 1

config :omg_watcher, OMG.Watcher.Tracer,
  disabled?: true,
  env: "test"

config :omg_watcher_info, child_chain_url: "http://localhost:9657"

config :omg_watcher_info, OMG.WatcherInfo.DB.Repo,
  ownership_timeout: 180_000,
  pool: Ecto.Adapters.SQL.Sandbox,
  # DATABASE_URL format is following `postgres://{user_name}:{password}@{host:port}/{database_name}`
  url: "postgres://omisego_dev:omisego_dev@localhost:5432/omisego_test"

config :omg_watcher_info, OMG.WatcherInfo.Tracer,
  disabled?: true,
  env: "test"

config :omg_watcher_info, environment: :test

config :omg_watcher_rpc, OMG.WatcherRPC.Web.Endpoint,
  http: [port: 7435],
  server: true

config :omg_watcher_rpc, OMG.WatcherRPC.Tracer,
  service: :omg_watcher_rpc,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  env: "test",
  type: :web
