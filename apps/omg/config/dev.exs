# dev config necessary to load project in iex
use Mix.Config

config :omg,
  ethereum_events_check_interval_ms: 500,
  coordinator_eth_height_check_interval_ms: 1_000,
  loggers: [Appsignal.Ecto, Ecto.LogEntry]
