# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :omg_rpc, OMG.RPC.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "TKO1TD87rXknWy9NhAGiEdv0cXm6W88/8G1E0uV0LISh998yZYNNPRZ5vfEexceb",
  render_errors: [view: OMG.RPC.Web.ErrorView, accepts: ~w(json)]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Poison

config :omg_rpc, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: OMG.RPC.Web.Router]
  }

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
