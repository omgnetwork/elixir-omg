use Mix.Config

config :ethereumex,
  url: "http://localhost:8545",
  http_options: [timeout: 60_000, recv_timeout: 60_000]

config :itest,
  reorg: System.get_env("REORG"),
  localchain_contract_env_path:
    System.get_env("LOCALCHAIN_CONTRACT_ADDRESSES") || "./../../localchain_contract_addresses.env"

config :tesla, adapter: Tesla.Adapter.Hackney

config :logger, level: :info
