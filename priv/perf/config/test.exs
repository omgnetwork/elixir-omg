use Mix.Config

config :ethereumex,
  url: System.get_env("ETHEREUM_RPC_URL") || "http://localhost:8545"

config :load_test,
  faucet_deposit_wei: trunc(:math.pow(10, 18) * 10),
  faucet_private_key:
    System.get_env("LOAD_TEST_FAUCET_PRIVATE_KEY") ||
      "0xd885a307e35738f773d8c9c63c7a3f3977819274638d04aaf934a1e1158513ce",
  child_chain_url: System.get_env("CHILD_CHAIN_URL") || "http://localhost:9656",
  fee_wei: 1,
  utxo_load_test_config: %{
    utxos_to_create_per_session: 1_000,
    transactions_per_session: 100
  },
  eth_vault_address: "0x4e3aeff70f022a6d4cc5947423887e7152826cf7"

config :ex_plasma,
  eip_712_domain: [
    name: "OMG Network",
    salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
    verifying_contract: "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f",
    version: "1"
  ]
