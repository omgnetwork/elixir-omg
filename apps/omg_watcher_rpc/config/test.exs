use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :omg_watcher_rpc, OMG.WatcherRPC.Web.Endpoint,
  http: [port: 7435],
  server: false
