use Mix.Config

config :briefly, directory: ["/tmp/omisego"]

config :byzantine_events,
  watcher_url: "localhost:7434",
  child_chain_url: "localhost:9656"

import_config "#{Mix.env()}.exs"
