use Mix.Config

# General application configuration
# see [here](README.md) for documentation
config :omg_watcher_informational,
  child_chain_url: "http://localhost:9656",
  namespace: OMG.WatcherInformational,
  ecto_repos: [OMG.WatcherInformational.DB.Repo],
  # 23 hours worth of blocks - this is how long the child chain server has to block spends from exiting utxos

  metrics_collection_interval: 60_000

# Configures the endpoint

config :omg_watcher_informational, OMG.WatcherInformational.DB.Repo,
  adapter: Ecto.Adapters.Postgres,
  # NOTE: not sure if appropriate, but this allows reasonable blocks to be written to unoptimized Postgres setup
  timeout: 60_000,
  connect_timeout: 60_000,
  url: "postgres://omisego_dev:omisego_dev@localhost/omisego_dev"

config :omg_watcher_informational, OMG.WatcherInformational.Tracer,
  service: :db,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :db

config :spandex_ecto, SpandexEcto.EctoLogger,
  service: :ecto,
  adapter: SpandexDatadog.Adapter,
  tracer: OMG.WatcherInformational.Tracer,
  otp_app: :omg_watcher_informational

import_config "#{Mix.env()}.exs"
