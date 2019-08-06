use Mix.Config

# bumping these timeouts into infinity - let's rely on test timeouts rather than these
config :ethereumex,
  url: "http://localhost:8545",
  http_options: [recv_timeout: :infinity]

config :omg_eth,
  client_monitor_interval_ms: 10,
  environment: :test,
  exit_period_seconds: 22,
  # an entry to fix a common reference path to the root directory of the umbrella project
  # this is useful because `mix test` and `mix coveralls --umbrella` have different views on the root dir when testing
  umbrella_root_dir: Path.join(__DIR__, "../../.."),
  ws_url: "ws://localhost:8546/ws",
  eth_node: "geth"
