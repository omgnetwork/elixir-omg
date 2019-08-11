use Mix.Config

# see [here](README.md) for documentation

config :omg_db,
  path: Path.join([System.get_env("HOME"), ".omg/data"])
