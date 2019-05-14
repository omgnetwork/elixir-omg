use Mix.Config

# see [here](README.md) for documentation

config :omg_db,
  type: :rocksdb,
  path: Path.join([System.get_env("HOME"), ".omg/data"]),
  leveldb: [server_module: OMG.DB.LevelDB.Server, server_name: OMG.DB.LevelDB.Server],
  rocksdb: [server_module: OMG.DB.RocksDB.Server, server_name: OMG.DB.RocksDB.Server]
