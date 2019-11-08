# Configuration via environment variables for deployment of Child Chain and Watcher releases

- "PORT" - Child Chain or Watcher API port. Defaults to 9656 for Child Chain and 7434 for Watcher.
- "HOSTNAME" - server domain name of Child Chain or Watcher. *mandatory*
- "DD_DISABLED" - boolean that allows you to turn on or of Datadog metrics. Defaults to true.
- "APP_ENV" - environment name in which the the application was deployed *mandatory*
- "DB_PATH" - directory of the KV db *mandatory*
- "ETHEREUM_RPC_URL" - address of Geth or Parity instance *mandatory*
- "ETHEREUM_WS_RPC_URL" - address of Geth or Parity instance with websocket flags *mandatory*
- "ETH_NODE" - Geth, Parity or Infura *mandatory*
- "SENTRY_DSN" - if not set, Sentry is disabled
- "DD_HOSTNAME" - Datadog hostname
- "DD_PORT" - Datadog agent UDP port for metrics
- "DD_APM_PORT" - Datadog TCP port for APM
- "BATCH_SIZE" - Datadog batch size for APM
- "SYNC_THRESHOLD" - Datadog sync threshold for APM

***Erlang VM configuration***

- "NODE_HOST" - The fully qualified host name of the current host.
- "ERLANG_COOKIE" - Magic cookie of the node.
- "REPLACE_OS_VARS" - An environment variable you export at runtime which instructed the tool to replace occurances of ${VAR} with the value from the system environment in the vm.args.

***Contract address configuration***
We allow a static configuration or a dynamic one, served as a http endpoint (one of them is mandatory).

- "ETHEREUM_NETWORK" - "RINKEBY" or "LOCALNETWORK"
- "CONTRACT_EXCHANGER_URL" - a server that can serve JSON in form of
```
{
  "plasma_framework_tx_hash":"<plasma_framework_tx_hash>",
  "plasma_framework":"<plasma_framework>",
  "eth_vault":"<eth_vault>",
  "erc20_vault":"<erc20_vault>",
  "payment_exit_game":"<payment_exit_game>",
  "authority_address":"<authority_address>"
}
```
Static configuration

- "ETHEREUM_NETWORK" - RINKEBY or LOCALNETWORK
- "RINKEBY_TXHASH_CONTRACT"
- "RINKEBY_AUTHORITY_ADDRESS"
- "RINKEBY_CONTRACT_ADDRESS_PLASMA_FRAMEWORK"
- "RINKEBY_CONTRACT_ADDRESS_ETH_VAULT
- "RINKEBY_CONTRACT_ADDRESS_ERC20_VAULT
- "RINKEBY_CONTRACT_ADDRESS_PAYMENT_EXIT_GAME"

or

- "LOCALNETWORK_TXHASH_CONTRACT"
- "LOCALNETWORK_AUTHORITY_ADDRESS"
- "LOCALNETWORK_CONTRACT_ADDRESS_PLASMA_FRAMEWORK"
- "LOCALNETWORK_CONTRACT_ADDRESS_ETH_VAULT
- "LOCALNETWORK_CONTRACT_ADDRESS_ERC20_VAULT
- "LOCALNETWORK_CONTRACT_ADDRESS_PAYMENT_EXIT_GAME"

***Required contract addresses***

The contract addresses that are required to be included in the `contract_addr` field (or `_CONTRACT_ADDRESS` JSON) are:

```
{
  "plasma_framework": "...",
  "eth_vault": "...",
  "erc20_vault": "...",
  "payment_exit_game": "..."
}
```

***Watcher only***

- "DATABASE_URL" - Postgres address *mandatory*
- "CHILD_CHAIN_URL" - Location of the Child Chain API *mandatory*
