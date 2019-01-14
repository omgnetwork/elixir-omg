use Mix.Config

config :briefly, directory: ["/tmp/omisego"]

config :omg_performance,
  child_chain_url: {:system, "CHILD_CHAIN_URL", "http://localhost:9656"}

import_config "#{Mix.env()}.exs"
