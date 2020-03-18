use Mix.Config

config :ethereumex,
  url: System.get_env("ETHEREUM_RPC_URL") || "https://ropsten.infura.io/v3/665408d4ac8d4b39a6b823f3f426448b"

config :load_test,
  child_chain_url: System.get_env("CHILD_CHAIN_URL") || "https://stress-e043a92-childchain-ropsten-01.omg.network/",
  fee_wei: 1,
  faucet_deposit_wei: :math.pow(10, 18) |> trunc,
  faucet_account: %{
    addr: "0x9133f35d9a964c894f152c0e7da66e832735a7a6",
    priv: "0x70ad9d48f90430607a340ea2e00495e1f84d2c50a4a3df0917e6161045b32378"
  },
  # 0.00000001 ETH
  initial_funds_wei: :math.pow(10, 9) |> trunc()

config :ex_plasma,
  authority_address: "0x87b8602c67c4419905dd1054f822132e7aa1a3b4",
  contract_address: "0x180ca7a9437e12fa4093a1a3d13648f25faad86f",
  eth_vault_address: "0x7b3425f47f1970f5c670fee895062eaf5799e481",
  ecr20_vault_address: "0x781c00fde3aa61fa44b991082c54619159634453",
  exit_game_address: "0x90579da613437d3e1f994aab98ff46fc5b31ab6d",
  eip_712_domain: [
    name: "OMG Network",
    salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
    verifying_contract: "0x180ca7a9437e12fa4093a1a3d13648f25faad86f",
    version: "1"
  ]
