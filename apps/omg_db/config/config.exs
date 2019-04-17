use Mix.Config

# see [here](README.md) for documentation

config :omg_db,
  # :leveldb, #:rocksdb
  type: :ets,
  # leveldb
  leveldb_path: Path.join([System.get_env("HOME"), ".omg/data"]),
  # leveldb
  server_module: OMG.DB.LevelDB.Server,
  # leveldb
  server_name: OMG.DB.LevelDB.Server
