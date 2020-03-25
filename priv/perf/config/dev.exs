use Mix.Config

config :ethereumex,
  # infura url includes the api key, thus passing by env var
  url: System.get_env("ETHEREUM_RPC_URL")

config :load_test,
  child_chain_url: "https://dev-a69c763-childchain-ropsten-01.omg.network",
  watcher_security_url: "https://dev-a69c763-watcher-ropsten-01.omg.network",
  watcher_info_url: "https://dev-a69c763-watcher-info-ropsten-01.omg.network",
  fee_wei: 1,
  # 0.000001 Ether
  faucet_deposit_wei: trunc(:math.pow(10, 12)),
  faucet_private_key: System.get_env("LOAD_TEST_FAUCET_PRIVATE_KEY"),
  # 0.0000001 ETH
  initial_funds_wei: trunc(:math.pow(10, 10)),
  eth_vault_address: "0xe637769f388f309e1cca8dd679a95a7b64a5bd06",
  utxo_load_test_config: %{
    concurrent_session: 100,
    utxos_to_create_per_session: 1,
    transactions_per_session: 10_000
  }

config :ex_plasma,
  eip_712_domain: [
    name: "OMG Network",
    salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
    verifying_contract: "0x1499442e7ee8c7cf2ae33f5e096d1a5b9c013cff",
    version: "1"
  ]
