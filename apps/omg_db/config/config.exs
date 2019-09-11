use Mix.Config

# see [here](README.md) for documentation

config :omg_db,
  type: :leveldb,
  leveldb: [server_module: OMG.DB.LevelDB.Server, server_name: OMG.DB.LevelDB.Server],
  rocksdb: [server_module: OMG.DB.RocksDB.Server, server_name: OMG.DB.RocksDB.Server],
  metrics_collection_interval: 60_000

if Mix.env() == :test or Mix.env() == :dev do
  import_config("#{Mix.env()}.exs")
end
