# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :omisego_watcher,
  namespace: OmiseGOWatcher,
  ecto_repos: [OmiseGOWatcher.Repo],

  ethereum_event_block_finality_margin: 10,
  ethereum_event_get_deposits_interval_ms: 60_000,
  ethereum_event_max_block_range_in_deposits_query: 5

# Configures the endpoint
config :omisego_watcher, OmiseGOWatcherWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "grt5Ef/y/jpx7AfLmrlUS/nfYJUOq+2e+1xmU4nphTm2x8WB7nLFCJ91atbSBrv5",
  render_errors: [view: OmiseGOWatcherWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: OmiseGOWatcher.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
