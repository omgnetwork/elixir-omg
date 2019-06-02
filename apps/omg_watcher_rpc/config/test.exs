use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :omg_watcher_rpc, OMG.WatcherRPC.Web.Endpoint,
  secret_key_base: "mg2kotN5N/2c3ZtCSOzgqEcx02rp0yfKRg71GRAkBJzluMmuWIfeeaEVdKA9i/ex",
  http: [port: 7435],
  server: false
