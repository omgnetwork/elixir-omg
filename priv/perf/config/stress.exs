use Mix.Config

config :ethereumex,
  url: System.get_env("ETHEREUM_RPC_URL")

config :load_test,
  child_chain_url: System.get_env("CHILD_CHAIN_URL"),
  fee_wei: 1,
  faucet_deposit_wei: trunc(:math.pow(10, 18)),
  faucet_account: %{
    addr: "0x9133f35d9a964c894f152c0e7da66e832735a7a6",
    priv: "0x70ad9d48f90430607a340ea2e00495e1f84d2c50a4a3df0917e6161045b32378"
  },
  # 0.00000001 ETH
  initial_funds_wei: trunc(:math.pow(10, 9)),
  eth_vault_address: "0x4e3aeff70f022a6d4cc5947423887e7152826cf7"

config :ex_plasma,
  eip_712_domain: [
    name: "OMG Network",
    salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
    verifying_contract: "0x5548cc80683b9bb968bca82fcde1c6799f9218a3",
    version: "1"
  ]
