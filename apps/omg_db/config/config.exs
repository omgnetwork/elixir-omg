use Mix.Config

config :omg_db,
  leveldb_path: Path.join([System.get_env("HOME"), ".omg/data"]),
  server_module: OMG.DB.LevelDBServer,
  server_name: OMG.DB.LevelDBServer
