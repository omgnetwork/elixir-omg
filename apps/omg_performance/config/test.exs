use Mix.Config

config :omg_eth, node_logging_in_debug: false

# `watcher_url` must match respective `:omg_watcher_rpc, OMG.WatcherRPC.Web.Endpoint`
config :omg_performance, watcher_url: "localhost:7435"
