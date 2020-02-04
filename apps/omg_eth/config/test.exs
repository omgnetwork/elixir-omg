use Mix.Config

# bumping these timeouts into infinity - let's rely on test timeouts rather than these
config :ethereumex,
  url: "http://localhost:8545",
  http_options: [recv_timeout: :infinity],
  id_reset: true

config :omg_eth,
  # Needed for test only to have some value of address when `:contract_address` is not set explicitly
  # required by the EIP-712 struct hash code
  contract_addr: %{plasma_framework: "0x0000000000000000000000000000000000000001"}

config :omg_eth,
  # Set check interval at (:ethereum_events_check_interval_ms / 2) == 400 so the listeners always get the latest height
  ethereum_height_check_interval_ms: 400,
  environment: :test,
  min_exit_period_seconds: 22,
  # NOTE: `umbrella_root_dir` fixes a common reference path to the root directory
  # of the umbrella project. This is useful because `mix test` and `mix coveralls --umbrella`
  # have different views on the root dir when testing.
  umbrella_root_dir: Path.join(__DIR__, "../../.."),
  ws_url: "ws://localhost:8546/ws",
  eth_node: :geth,
  run_test_eth_dev_node: true
