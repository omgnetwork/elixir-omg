use Mix.Config

config :omisego_eth,
    contract: "contract_addres",
    omg_addr: "omg_addres",
    root_path: "../../"

config :ethereumex,
  scheme: "http",
  host: "localhost",
  port: 8545,
  url: "http://localhost:8545"
