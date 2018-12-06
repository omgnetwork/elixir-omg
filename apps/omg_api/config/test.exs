use Mix.Config

config :omg_api,
  eth_deposit_finality_margin: 1,
  ethereum_status_check_interval_ms: 50,
  fee_specs_file_path: "./../../fee_specs.json"
