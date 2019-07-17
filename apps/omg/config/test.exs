use Mix.Config

config :omg,
  deposit_finality_margin: 1,
  ethereum_events_check_interval_ms: 50,
  coordinator_eth_height_check_interval_ms: 100,
  client_monitor_interval_ms: 50,
  environment: :test,
  # an entry to fix a common reference path to the root directory of the umbrella project
  # this is useful because `mix test` and `mix coveralls --umbrella` have different views on the root dir when testing
  umbrella_root_dir: Path.join(__DIR__, "../../..")

config :omg, OMG.Utils.Tracer, env: "test"
