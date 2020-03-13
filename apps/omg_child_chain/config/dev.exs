# dev config necessary to load project in iex
use Mix.Config

config :omg_child_chain,
  block_queue_eth_height_check_interval_ms: 1_000
