use Mix.Config

config :omg,
  deposit_finality_margin: 1,
  ethereum_events_check_interval_ms: 10,
  coordinator_eth_height_check_interval_ms: 10,
  environment: :test,
  # NOTE: `umbrella_root_dir` fixes a common reference path to the root directory
  # of the umbrella project. This is useful because `mix test` and `mix coveralls --umbrella`
  # have different views on the root dir when testing.
  umbrella_root_dir: Path.join(__DIR__, "../../..")
