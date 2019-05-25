# dev config necessary to load project in iex
use Mix.Config

config :omg_child_chain,
  ethereum_events_check_interval_ms: 500,
  block_queue_eth_height_check_interval_ms: 1_000
