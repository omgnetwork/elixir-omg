use Mix.Config

config :briefly, directory: ["/tmp/omisego"]

# `watcher_url` must match respective `:omg_watcher_rpc, OMG.WatcherRPC.Web.Endpoint`
config :omg_performance, watcher_url: "localhost:7434"

import_config "#{Mix.env()}.exs"
