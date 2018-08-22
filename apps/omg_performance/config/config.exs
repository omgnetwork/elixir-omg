use Mix.Config

config :briefly, directory: ["/tmp/omisego"]

import_config "#{Mix.env()}.exs"
