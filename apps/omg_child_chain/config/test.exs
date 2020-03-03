use Mix.Config

config :omg_child_chain,
  block_queue_eth_height_check_interval_ms: 100,
  fee_adapter_check_interval_ms: 1_000,
  fee_buffer_duration_ms: 5_000
