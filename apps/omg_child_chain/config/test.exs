use Mix.Config

config :omg_child_chain,
  block_queue_eth_height_check_interval_ms: 100,
  fee_file_check_interval_ms: 1_000,
  fee_buffer_duration_ms: 5_000,
  fee_specs_file_path: Path.join(Path.dirname(__DIR__), "priv/fee_specs.json")
