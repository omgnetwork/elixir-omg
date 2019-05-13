use Mix.Config

# see [here](README.md) for documentation

config :omg_db,
  # :leveldb, #:ets
  type: :leveldb,
  # leveldb
  leveldb_path: Path.join([System.get_env("HOME"), ".omg/data"]),
  # leveldb
  server_module: OMG.DB.LevelDB.Server,
  # leveldb
  server_name: OMG.DB.LevelDB.Server,
  r_server_module: OMG.DB.RocksDB.Server,
  # leveldb
  r_server_name: OMG.DB.RocksDB.Server
