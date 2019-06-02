use Mix.Config

config :omg_watcher, OMG.Watcher.DB.Repo,
  adapter: Ecto.Adapters.Postgres,
  # DATABASE_URL format is following `postgres://{user_name}:{password}@{host:port}/{database_name}`
  url: {:system, "DATABASE_URL", ""}

config :omg_watcher, environment: :prod
