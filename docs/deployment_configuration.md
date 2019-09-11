# Configuration via environment variables for deployment of Child Chain and Watcher releases

- "PORT" - Child Chain or Watcher API port. Defaults to 9656 for Child Chain and 7434 for Watcher.
- "HOSTNAME" - server domain name of Child Chain or Watcher. *mandatory*
- "DD_DISABLED" - boolean that allows you to turn on or of Datadog metrics. Defaults to true.
- "APP_ENV" - environment name in which the the application was deployed *mandatory*
- "DB_TYPE" - RocksDB or LevelDB, defaults to LevelDB
- "DB_PATH" - directory of the KV db *mandatory*
- "EXIT_PERIOD_SECONDS" - defaults to `604800`
- "ETHEREUM_RPC_URL" - address of Geth or Parity instance *mandatory*
- "ETHEREUM_WS_RPC_URL" - address of Geth or Parity instance with websocket flags *mandatory*
- "ETH_NODE" - Geth or Parity *mandatory*
- "SENTRY_DSN" - if not set, Sentry is disabled
- "DD_HOSTNAME" - Datadog hostname
- "DD_PORT" - Datadog agent UDP port for metrics
- "DD_APM_PORT" - Datadog TCP port for APM
- "BATCH_SIZE" - Datadog batch size for APM
- "SYNC_THRESHOLD" - Datadog sync threshold for APM

***Contract address configuration***
We allow a static configuration or a dynamic one, served as a http endpoint (one of them is mandatory).

- "ETHEREUM_NETWORK" - "RINKEBY" or "LOCALNETWORK"
- "CONTRACT_EXCHANGER_URL" - a server that can serve JSON in form of
```
{
  "authority_addr": "<authority_address>",
  "contract_addr": "<contract_address>",
  "txhash_contract": "<txhash_contract>"
}
```
Static configuration

- "ETHEREUM_NETWORK" - RINKEBY or LOCALNETWORK
- "RINKEBY_TXHASH_CONTRACT"
- "RINKEBY_AUTHORITY_ADDRESS"
- "RINKEBY_CONTRACT_ADDRESS"
or
- "LOCALNETWORK_TXHASH_CONTRACT"
- "LOCALNETWORK_AUTHORITY_ADDRESS"
- "LOCALNETWORK_CONTRACT_ADDRESS"

***Watcher only***

- "DATABASE_URL" - Postgres address *mandatory*
- "CHILD_CHAIN_URL" - Location of the Child Chain API *mandatory*
