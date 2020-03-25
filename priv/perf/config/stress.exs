use Mix.Config

config :ethereumex,
  url: System.get_env("ETHEREUM_RPC_URL")

config :load_test,
  child_chain_url: "https://stress-a69c763-childchain-ropsten-01.omg.network",
  watcher_security_url: "https://stress-a69c763-watcher-ropsten-01.omg.network",
  watcher_info_url: "https://stress-a69c763-watcher-info-ropsten-01.omg.network",
  # 0.00003 ETH
  fee_wei: trunc(:math.pow(10, 13) * 3),
  faucet_deposit_wei: trunc(:math.pow(10, 16)),
  faucet_private_key: System.get_env("LOAD_TEST_FAUCET_PRIVATE_KEY"),
  # 0.00000001 ETH
  initial_funds_wei: trunc(:math.pow(10, 9)),
  eth_vault_address: "0x3721d695bc4ee79c0402572dbd04a445acc69548",
  utxo_load_test_config: %{
    concurrent_session: 10,
    utxos_to_create_per_session: 1,
    transactions_per_session: 10
  }

config :ex_plasma,
  eip_712_domain: [
    name: "OMG Network",
    salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
    verifying_contract: "0x5548cc80683b9bb968bca82fcde1c6799f9218a3",
    version: "1"
  ]
