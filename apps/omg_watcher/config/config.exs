# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :omg_watcher,
  namespace: OMG.Watcher,
  ecto_repos: [OMG.Watcher.DB.Repo],
  # 4 hours worth of blocks - this is how long the child chain server has to block spends from exiting utxos
  exit_processor_sla_margin: 4 * 4 * 60,
  maximum_block_withholding_time_ms: 1_200_000,
  block_getter_loops_interval_ms: 500,
  maximum_number_of_unapplied_blocks: 50,
  exit_finality_margin: 12,
  block_getter_reorg_margin: 200,
  convenience_api_mode: false,
  enable_cors: true

# Configures the endpoint
config :omg_watcher, OMG.Watcher.Web.Endpoint,
  secret_key_base: "grt5Ef/y/jpx7AfLmrlUS/nfYJUOq+2e+1xmU4nphTm2x8WB7nLFCJ91atbSBrv5",
  render_errors: [view: OMG.Watcher.Web.View.ErrorView, accepts: ~w(json)],
  pubsub: [name: OMG.Watcher.PubSub, adapter: Phoenix.PubSub.PG2],
  instrumenters: [Appsignal.Phoenix.Instrumenter]

config :omg_watcher, OMG.Watcher.DB.Repo,
  adapter: Ecto.Adapters.Postgres,
  # NOTE: not sure if appropriate, but this allows reasonable blocks to be written to unoptimized Postgres setup
  timeout: 60_000,
  connect_timeout: 60_000

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
