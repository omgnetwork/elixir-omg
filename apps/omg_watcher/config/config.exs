use Mix.Config

config :omg_watcher, child_chain_url: "http://localhost:9656"

config :omg_watcher,
  # 23 hours worth of blocks - this is how long the child chain server has to block spends from exiting utxos
  exit_processor_sla_margin: 23 * 60 * 4,
  # this means we don't want the `sla_margin` above be larger than the `min_exit_period`
  exit_processor_sla_margin_forced: false,
  maximum_block_withholding_time_ms: 15 * 60 * 60 * 1000,
  block_getter_loops_interval_ms: 500,
  maximum_number_of_unapplied_blocks: 50,
  exit_finality_margin: 12,
  block_getter_reorg_margin: 200,
  metrics_collection_interval: 60_000

config :omg_watcher, OMG.Watcher.Tracer,
  service: :omg_watcher,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :omg_watcher

import_config "#{Mix.env()}.exs"
