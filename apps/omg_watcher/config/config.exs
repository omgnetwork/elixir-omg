# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# child chain url
config :omg_watcher, child_chain_url: "http://localhost:9656"

# General application configuration
# see [here](README.md) for documentation
config :omg_watcher,
  namespace: OMG.Watcher,
  ecto_repos: [OMG.Watcher.DB.Repo],
  # 23 hours worth of blocks - this is how long the child chain server has to block spends from exiting utxos
  exit_processor_sla_margin: 23 * 60 * 4,
  maximum_block_withholding_time_ms: 1_200_000,
  block_getter_loops_interval_ms: 500,
  maximum_number_of_unapplied_blocks: 50,
  exit_finality_margin: 12,
  block_getter_reorg_margin: 200,
  metrics_collection_interval: 60_000

# Configures the endpoint

config :omg_watcher, OMG.Watcher.DB.Repo,
  adapter: Ecto.Adapters.Postgres,
  # NOTE: not sure if appropriate, but this allows reasonable blocks to be written to unoptimized Postgres setup
  timeout: 60_000,
  connect_timeout: 60_000,
  url: "postgres://omisego_dev:omisego_dev@localhost/omisego_dev"

config :omg_watcher, OMG.Watcher.Tracer,
  service: :db,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :db

config :spandex_ecto, SpandexEcto.EctoLogger,
  service: :ecto,
  adapter: SpandexDatadog.Adapter,
  tracer: OMG.Watcher.Tracer,
  otp_app: :omg_watcher

import_config "#{Mix.env()}.exs"
