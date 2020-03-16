use Mix.Config

# Better adapter for tesla.
# default httpc would fail when doing post request without param.
# https://github.com/googleapis/elixir-google-api/issues/26#issuecomment-360209019
config :tesla, adapter: Tesla.Adapter.Hackney

config :load_test,
  pool_size: 5000,
  max_connection: 5000

import_config "#{Mix.env()}.exs"
