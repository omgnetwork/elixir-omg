use Mix.Config

# Better adapter for tesla.
# default httpc would fail when doing post request without param.
# https://github.com/googleapis/elixir-google-api/issues/26#issuecomment-360209019
config :tesla, adapter: Tesla.Adapter.Hackney

config :load_test,
  pool_size: 5000,
  max_connection: 5000,
  faucet_default_funds: trunc(:math.pow(10, 18) * 50),
  initial_funds_wei: trunc(:math.pow(10, 17)),
  deposit_finality_margin: 10

config :logger, :console,
  format: "$date $time [$level] $metadata⋅$message⋅\n",
  discard_threshold: 2000,
  metadata: [:module, :function, :request_id, :trace_id, :span_id]

ethereum_client_timeout_ms = 20_000

config :ethereumex,
  http_options: [recv_timeout: ethereum_client_timeout_ms]

import_config "#{Mix.env()}.exs"
