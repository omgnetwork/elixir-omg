use Mix.Config

config :omg_watcher, child_chain_url: "http://localhost:9657"

config :omg_watcher,
  block_getter_loops_interval_ms: 50,
  # NOTE `exit_processor_sla_margin` can't be made shorter. At 3 it sometimes
  # causes :unchallenged_exit because `geth --dev` is too fast
  exit_processor_sla_margin: 5,
  # this means we allow the `sla_margin` above be larger than the `min_exit_period`
  exit_processor_sla_margin_force: true,
  # NOTE: `maximum_block_withholding_time_ms` must be here - one of our integration tests
  # actually fakes block withholding to test something
  maximum_block_withholding_time_ms: 1_000,
  exit_finality_margin: 1,
  # NOTE: `umbrella_root_dir` fixes a common reference path to the root directory
  # of the umbrella project. This is useful because `mix test` and `mix coveralls --umbrella`
  # have different views on the root dir when testing.
  umbrella_root_dir: Path.join(__DIR__, "../../..")

config :omg_watcher, OMG.Watcher.Tracer,
  disabled?: true,
  env: "test"

config :omg_watcher, environment: :test
