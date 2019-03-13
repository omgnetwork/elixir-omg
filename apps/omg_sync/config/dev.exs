use Mix.Config

config :omg_sync,
  ethereum_events_check_interval_ms: 500,
  block_queue_eth_height_check_interval_ms: 1_000,
  coordinator_eth_height_check_interval_ms: 1_000,
  loggers: [Appsignal.Ecto, Ecto.LogEntry]
