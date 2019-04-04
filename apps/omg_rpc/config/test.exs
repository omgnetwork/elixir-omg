use Mix.Config

# We need to start OMG.RPC.Web.Endpoint with HTTP server for Performance and Watcher tests to work
# as a drawback lightweight (without HTTP server) controller tests are no longer an option.
config :omg_rpc, OMG.RPC.Web.Endpoint,
  secret_key_base: "dQOUY43PWqdyl6Sv7VTvp7aS/J8gpPsnzVOSy2K2Oo8MbyZ/0chS90duekNd4d8t",
  http: [port: 9656],
  server: true
