use Mix.Config

config :load_testing,
  child_chain_url: "https://dev-7c3f796-childchain-ropsten-01.omg.network/",
  watcher_security_url: "https://dev-7c3f796-watcher-ropsten-01.omg.network/",
  watcher_info_url: "https://dev-7c3f796-watcher-info-ropsten-01.omg.network/",
  fee_wei: 1,
  faucet_deposit_wei: :math.pow(10, 18) |> trunc,
  faucet_account: %{
    addr: "0x9133f35d9a964c894f152c0e7da66e832735a7a6",
    priv: "0x70ad9d48f90430607a340ea2e00495e1f84d2c50a4a3df0917e6161045b32378"
  },
  # 0.0000001 ETH
  initial_funds_wei: :math.pow(10, 10) |> trunc()

config :ex_plasma,
  authority_address: "0x6514696e41c6b855cd7e72f228fd105ac34b867b",
  contract_address: "0xeeed49aff230ce3d8ae5ef044555f3c29e8b65d0",
  eth_vault_address: "0x77cb4e1472298326275aabd54cd94810599e7090",
  ecr20_vault_address: "0x2649b4e6711137070de27fb8c58ef458e6bcc016",
  exit_game_address: "0xf401dce51b7d8d4c4a0250cc259ebe281b1f4d7b",
  eip_712_domain: [
    name: "OMG Network",
    salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
    verifying_contract: "0xeeed49aff230ce3d8ae5ef044555f3c29e8b65d0",
    version: "1"
  ]
