use Mix.Config

# Better adapter for tesla.
# default httpc would fail when doing post request without param.
# https://github.com/googleapis/elixir-google-api/issues/26#issuecomment-360209019
config :tesla, adapter: Tesla.Adapter.Hackney

ethereum_client_timeout_ms = 20_000

config :ethereumex,
  http_options: [recv_timeout: ethereum_client_timeout_ms],
  url: System.get_env("ETHEREUM_RPC_URL") || "http://localhost:8545"

config :load_test,
  pool_size: 5000,
  max_connection: 5000,
  retry_sleep: System.get_env("RETRY_SLEEP") || 1_000,
  child_chain_url: System.get_env("CHILD_CHAIN_URL") || "http://localhost:9656",
  watcher_security_url: System.get_env("WATCHER_SECURITY_URL") || "http://localhost:7434",
  watcher_info_url: System.get_env("WATCHER_INFO_URL") || "http://localhost:7534",
  faucet_private_key:
    System.get_env("LOAD_TEST_FAUCET_PRIVATE_KEY") ||
      "0xd885a307e35738f773d8c9c63c7a3f3977819274638d04aaf934a1e1158513ce",
  eth_vault_address: System.get_env("CONTRACT_ADDRESS_ETH_VAULT"),
  contract_address_payment_exit_game: System.get_env("CONTRACT_ADDRESS_PAYMENT_EXIT_GAME"),
  child_block_interval: 1000,
  contract_address_plasma_framework: System.get_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK"),
  erc20_vault_address: System.get_env("CONTRACT_ADDRESS_ERC20_VAULT"),
  test_currency: "0x0000000000000000000000000000000000000000",
  faucet_deposit_amount: trunc(:math.pow(10, 14)),
  fee_amount: 1,
  deposit_finality_margin: 10,
  gas_price: 2_000_000_000

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

import_config "#{Mix.env()}.exs"
