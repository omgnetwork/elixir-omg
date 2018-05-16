use Mix.Config

config :omisego_eth, child_block_interval: 1000

config :omisego_db, leveldb_path: Path.join([System.get_env("HOME"), ".omisego/operator_data"])

# import_config "#{Mix.env}.exs"
