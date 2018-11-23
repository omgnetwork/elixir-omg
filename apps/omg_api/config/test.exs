use Mix.Config

config :omg_api,
  eth_deposit_finality_margin: 1,
  eth_submission_finality_margin: 2,
  ethereum_event_check_height_interval_ms: 50,
  rootchain_height_sync_interval_ms: 50,
  child_block_minimal_enquque_gap: 1
