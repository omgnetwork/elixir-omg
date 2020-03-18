use Mix.Config

config :ethereumex,
  url: System.get_env("ETHEREUM_RPC_URL") || "http://localhost:8545"

config :load_test,
  faucet_deposit_wei: trunc(:math.pow(10, 18) * 10),
  child_chain_url: System.get_env("CHILD_CHAIN_URL") || "http://localhost:9656",
  fee_wei: 1,
  utxo_load_test_config: %{
    utxos_to_create_per_session: 1_000,
    transactions_per_session: 100
  }

config :ex_plasma,
  authority_address: "0xc0f780dfc35075979b0def588d999225b7ecc56f",
  contract_address: "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f",
  eth_vault_address: "0x4e3aeff70f022a6d4cc5947423887e7152826cf7",
  exit_game_address: "0x89afce326e7da55647d22e24336c6a2816c99f6b",
  eip_712_domain: [
    name: "OMG Network",
    salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
    verifying_contract: "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f",
    version: "1"
  ]
