# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :omg_watcher_rpc, OMG.WatcherRPC.Web.Endpoint,
  secret_key_base: {:system, "SECRET_KEY_BASE"},
  render_errors: [view: OMG.WatcherRPC.Web.Views.Error, accepts: ~w(json)],
  pubsub: [name: OMG.WatcherRPC.PubSub, adapter: Phoenix.PubSub.PG2],
  # instrumenters: [Appsignal.Phoenix.Instrumenter],
  enable_cors: true

import_config "#{Mix.env()}.exs"
