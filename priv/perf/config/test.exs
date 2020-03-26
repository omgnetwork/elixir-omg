use Mix.Config

config :ethereumex,
  url: System.get_env("ETHEREUM_RPC_URL") || "http://localhost:8545"

config :load_test,
  child_chain_url: System.get_env("CHILD_CHAIN_URL") || "http://localhost:9656",
  watcher_security_url: System.get_env("WATCHER_SECURITY_URL") || "http://localhost:9656",
  watcher_info_url: System.get_env("WATCHER_INFO_URL") || "http://localhost:9656",
  fee_wei: 1,
  faucet_deposit_wei: trunc(:math.pow(10, 18) * 10),
  faucet_private_key: System.get_env("LOAD_TEST_FAUCET_PRIVATE_KEY"),
  eth_vault_address: System.get_env("CONTRACT_ADDRESS_ETH_VAULT"),
  utxo_load_test_config: %{
    utxos_to_create_per_session: 1_000,
    transactions_per_session: 100
  }

config :ex_plasma,
  eip_712_domain: [
    name: "OMG Network",
    salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
    verifying_contract: System.get_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK"),
    version: "1"
  ]
