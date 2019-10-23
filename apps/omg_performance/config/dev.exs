use Mix.Config

config :omg_eth,
  # Needed for test only to have some value of address when `:contract_address` is not set explicitly
  # required by the EIP-712 struct hash code
  contract_addr: %{plasma_framework: "0x0000000000000000000000000000000000000001"}

config :omg_eth, node_logging_in_debug: false
