use Mix.Config

config :load_test,
  pool_size: 20_000,
  max_connection: 20_000,
  child_chain_url: "https://stress-e043a92-childchain-ropsten-01.omg.network/",
  watcher_security_url: "https://stress-e043a92-watcher-ropsten-01.omg.network/",
  watcher_info_url: "https://stress-e043a92-watcher-info-ropsten-01.omg.network/"
