# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :omg_rpc,
  child_chain_api_module: OMG.ChildChain

# Configures the endpoint
config :omg_rpc, OMG.RPC.Web.Endpoint,
  secret_key_base: {:system, "SECRET_KEY_BASE"},
  render_errors: [view: OMG.RPC.Web.Views.Error, accepts: ~w(json)],
  instrumenters: [Appsignal.Phoenix.Instrumenter]

# Use Poison for JSON parsing in Phoenix
config :phoenix,
  json_library: Jason,
  serve_endpoints: true,
  persistent: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
