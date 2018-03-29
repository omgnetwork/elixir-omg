use Mix.Config

config :omisego_db,
  leveldb_path: Path.join([System.get_env("HOME"), ".omisego/data"]),
  server_module: OmiseGO.DB.LevelDBServer,
  server_name: OmiseGO.DB.LevelDBServer

# import_config "#{Mix.env}.exs"
