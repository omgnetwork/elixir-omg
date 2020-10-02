# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :front,
  ecto_repos: [Front.Repo]

# Configures the endpoint
config :front, FrontWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "ozDFL6Hr0KLUEh4i55m+YBO4ukTTagoGM8i2ju9i8pXaFGfjZuTHx56R+wseZhtg",
  render_errors: [view: FrontWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Front.PubSub,
  live_view: [signing_salt: "qSCz/ACR"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
