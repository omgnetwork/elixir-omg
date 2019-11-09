# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :omg_watcher_security,
  # 23 hours worth of blocks - this is how long the child chain server has to block spends from exiting utxos
  exit_processor_sla_margin: 23 * 60 * 4,
  maximum_block_withholding_time_ms: 1_200_000,
  block_getter_loops_interval_ms: 500,
  maximum_number_of_unapplied_blocks: 50,
  exit_finality_margin: 12,
  block_getter_reorg_margin: 200,
  metrics_collection_interval: 60_000
