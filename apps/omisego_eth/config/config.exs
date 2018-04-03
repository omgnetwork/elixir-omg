use Mix.Config

config :porcelain, :goon_warn_if_missing, false

config :omisego_eth,
    contract: "contract_addres",
    txhash_contract: "contract_hash_transaction",
    omg_addr: "omg_addres",
    root_path: "../../"

config :ethereumex,
  scheme: "http",
  host: "localhost",
  port: 8545,
  url: "http://localhost:8545"
