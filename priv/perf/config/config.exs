use Mix.Config

# Better adapter for tesla.
# default httpc would fail when doing post request without param.
# https://github.com/googleapis/elixir-google-api/issues/26#issuecomment-360209019
config :tesla, adapter: Tesla.Adapter.Hackney

config :ethereumex,
  url: System.get_env("ETHEREUM_RPC_URL")

config :load_test,
  pool_size: 5000,
  max_connection: 5000,
  child_chain_url: System.get_env("CHILD_CHAIN_URL"),
  watcher_security_url: System.get_env("WATCHER_SECURITY_URL"),
  watcher_info_url: System.get_env("WATCHER_INFO_URL"),
  faucet_private_key: System.get_env("LOAD_TEST_FAUCET_PRIVATE_KEY"),
  eth_vault_address: System.get_env("CONTRACT_ADDRESS_ETH_VAULT"),
  faucet_deposit_wei: trunc(:math.pow(10, 14)),
  initial_funds_wei: trunc(:math.pow(10, 7)),
  fee_wei: 1,
  deposit_finality_margin: 10

config :ex_plasma,
  eip_712_domain: [
    name: "OMG Network",
    salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
    verifying_contract: System.get_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK"),
    version: "1"
  ]

config :logger, :console,
  format: "$date $time [$level] $metadata⋅$message⋅\n",
  discard_threshold: 2000,
  metadata: [:module, :function, :request_id, :trace_id, :span_id]

ethereum_client_timeout_ms = 20_000

config :ethereumex,
  http_options: [recv_timeout: ethereum_client_timeout_ms]

import_config "#{Mix.env()}.exs"
