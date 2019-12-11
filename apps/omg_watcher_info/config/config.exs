use Mix.Config

# General application configuration
# see [here](README.md) for documentation
config :omg_watcher_info,
  child_chain_url: "http://localhost:9656",
  namespace: OMG.WatcherInfo,
  ecto_repos: [OMG.WatcherInfo.DB.Repo],
  metrics_collection_interval: 60_000

# Configures the endpoint

config :omg_watcher_info, OMG.WatcherInfo.DB.Repo,
  adapter: Ecto.Adapters.Postgres,
  # NOTE: not sure if appropriate, but this allows reasonable blocks to be written to unoptimized Postgres setup
  timeout: 60_000,
  connect_timeout: 60_000,
  url: "postgres://omisego_dev:omisego_dev@localhost/omisego_dev"

config :omg_watcher_info, OMG.WatcherInfo.Tracer,
  service: :db,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :db

config :spandex_ecto, SpandexEcto.EctoLogger,
  service: :ecto,
  adapter: SpandexDatadog.Adapter,
  tracer: OMG.WatcherInfo.Tracer,
  otp_app: :omg_watcher_info

import_config "#{Mix.env()}.exs"
