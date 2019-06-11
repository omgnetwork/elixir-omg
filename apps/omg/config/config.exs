use Mix.Config

# see [here](README.md) for documentation

config :omg,
  deposit_finality_margin: 10,
  ethereum_events_check_interval_ms: 500,
  coordinator_eth_height_check_interval_ms: 6_000,
  client_monitor_interval_ms: 2500

config :omg, :eip_712_domain,
  name: "OMG Network",
  version: "1",
  salt: "fad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83"

import_config "#{Mix.env()}.exs"
