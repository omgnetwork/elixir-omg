use Mix.Config

config :engine, Engine.Repo,
  database: "childchain_repo",
  username: "omisego_dev",
  password: "omisego_dev",
  hostname: "localhost"

config :engine, ecto_repos: [Engine.Repo]
