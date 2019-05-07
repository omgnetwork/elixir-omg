use Mix.Config

# see [here](README.md) for documentation

config :omg,
  deposit_finality_margin: 10,
  ethereum_events_check_interval_ms: {:system, "ETHEREUM_EVENTS_CHECK_INTERVAL_MS", 500, {String, :to_integer}},
  coordinator_eth_height_check_interval_ms:
    {:system, "COORDINATOR_ETH_HEIGHT_CHECK_INTERVAL_MS", 1_000, {String, :to_integer}},
  client_monitor_interval_ms: 500

config :omg, :eip_712_domain,
  name: "OMG Network",
  version: "1",
  chain_id: 4,
  verifying_contract: "44de0ec539b8c4a4b530c78620fe8320167f2f74",
  salt: "fad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83"

import_config "#{Mix.env()}.exs"
