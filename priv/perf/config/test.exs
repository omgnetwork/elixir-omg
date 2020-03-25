use Mix.Config

config :ethereumex,
  url: "http://localhost:8545"

config :load_test,
  faucet_deposit_wei: trunc(:math.pow(10, 15)),
  faucet_private_key: "0xd885a307e35738f773d8c9c63c7a3f3977819274638d04aaf934a1e1158513ce",
  child_chain_url: "http://localhost:9656",
  watcher_security_url: "http://localhost:7434",
  watcher_info_url: "http://localhost:7534",
  fee_wei: 1,
  eth_vault_address: "0x4e3aeff70f022a6d4cc5947423887e7152826cf7",
  utxo_load_test_config: %{
    concurrent_session: 4,
    utxos_to_create_per_session: 1_000,
    transactions_per_session: 100
  }

config :ex_plasma,
  eip_712_domain: [
    name: "OMG Network",
    salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
    verifying_contract: "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f",
    version: "1"
  ]
