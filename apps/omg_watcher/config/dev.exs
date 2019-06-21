use Mix.Config

config :omg_watcher, environment: :dev

# Configure your database
config :omg_watcher, OMG.Watcher.DB.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool_size: 10,
  # DATABASE_URL format is following `postgres://{user_name}:{password}@{host:port}/{database_name}`
  url: {:system, "DATABASE_URL", "postgres://omisego_dev:omisego_dev@localhost/omisego_dev"}
