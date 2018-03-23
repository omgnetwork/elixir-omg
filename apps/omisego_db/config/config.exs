use Mix.Config

config :omisego_db,
  leveldb_path: Path.join([System.get_env("HOME"), ".omisego/data"])

config :omisego_db,
  server_module: OmiseGO.DB.LevelDBServer

config :omisego_db,
  server_name: OmiseGO.DB.LevelDBServer

# import_config "#{Mix.env}.exs"
