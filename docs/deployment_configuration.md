# Configuration via environment variables for deployment of Child Chain, Watcher and Watcher Info releases

***Child Chain, Watcher and Watcher Info***

- "PORT" - Child Chain or Watcher API port. Defaults to 9656 for Child Chain and 7434 for Watcher.
- "HOSTNAME" - server domain name of Child Chain or Watcher. *mandatory*
- "DD_DISABLED" - boolean that allows you to turn on or of Datadog metrics. Defaults to true.
- "APP_ENV" - environment name in which the the application was deployed. *mandatory*
- "DB_PATH" - directory of the KV db. *mandatory*
- "ETHEREUM_RPC_URL" - address of Geth or Parity instance. *mandatory*
- "ETH_NODE" - Geth, Parity or Infura. *mandatory*
- "SENTRY_DSN" - if not set, Sentry is disabled.
- "DD_HOSTNAME" - Datadog hostname.
- "DD_PORT" - Datadog agent UDP port for metrics.
- "DD_APM_PORT" - Datadog TCP port for APM.
- "BATCH_SIZE" - Datadog batch size for APM.
- "SYNC_THRESHOLD" - Datadog sync threshold for APM.
- "ETHEREUM_BLOCK_TIME_SECONDS" - Should mirror Ethereum network's setting, defaults to 15 seconds.
- "ETHEREUM_EVENTS_CHECK_INTERVAL_MS" - the frequency of HTTP requests towards the Ethereum clients and scanning for interested events. Should be less then average block time (10 to 20 seconds) on Ethereum mainnet.
- "ETHEREUM_STALLED_SYNC_THRESHOLD_MS" - the threshold before considering an unchanging Ethereum block height to be considered a stalled sync. Should be slightly larger than the expected block time.
- "LOGGER_BACKEND" - Ink or console. Ink will encode logs as json (useful for Datadog). Console will use the default elixir Logger backend. Default is Ink.

***Child Chain only***

- "BLOCK_SUBMIT_MAX_GAS_PRICE" - The maximum gas price to use for block submission. The first block submission after application boot will use the max price. The gas price gradually adjusts on subsequent blocks to reach the current optimum price. Defaults to `20000000000` (20 Gwei).
- "BLOCK_SUBMIT_STALL_THRESHOLD_BLOCKS" - The number of root chain blocks passed until a child chain block pending submission is considered stalled. Defaults to `4` root chain blocks.
- "BLOCK_SUBMIT_GAS_PRICE_STRATEGY" - The gas price strategy to use for block submission. Note that all strategies will still run, but only the one configured here will be used for actual submission. Suppots `LEGACY`, `BLOCK_PERCENTILE` and `POISSON`. Defaults to `LEGACY`.
- "FEE_ADAPTER" - The adapter to use to populate the fee specs. Either `file` or `feed` (case-insensitive). Defaults to `file` with an empty fee specs.
- "FEE_CLAIMER_ADDRESS" - 20-bytes HEX-encoded string of Ethereum address of Fee Claimer.
- "FEE_BUFFER_DURATION_MS" - Buffer period during which a fee is still valid after being updated.
- "FEE_SPECS_FILE_PATH" - The path to the fee specs file including the file name.  Only applicable when `FEE_ADAPTER=file`.
- "FEE_FEED_URL" - URL to fee feed service. Only applicable when `FEE_ADAPTER=feed`.
- "FEE_CHANGE_TOLERANCE_PERCENT" - Positive integer describes significance of price change. When price in new reading changes above tolerance level, prices are updated immediately. Otherwise update interval is preserved. Only applicable when `FEE_ADAPTER=feed`.
- "STORED_FEE_UPDATE_INTERVAL_MINUTES" - Positive integer describes time interval in minutes. The updates of token prices are carried out in update intervals as long as the changes are within tolerance. Only applicable when `FEE_ADAPTER=feed`.

***Watcher and Watcher Info only***

- "CHILD_CHAIN_URL" - Location of the Child Chain API. *mandatory*
- "EXIT_PROCESSOR_SLA_MARGIN" - Number of Ethereum blocks since start of an invalid exit, before `unchallenged_exit` is reported to prompt to mass exit. Must be smaller than "MIN_EXIT_PERIOD_SECONDS", unless "EXIT_PROCESSOR_SLA_MARGIN_FORCED=TRUE".

***Watcher Info only***

- "DATABASE_URL" - Postgres address *mandatory*
- "WATCHER_INFO_DB_POOL_SIZE" - The size of the database connection pool. Defaults to `10`.
- "WATCHER_INFO_DB_POOL_QUEUE_TARGET_MS" - The maximum time to wait for a DB connection in milliseconds. Defaults to `50`.
- "WATCHER_INFO_DB_POOL_QUEUE_INTERVAL_MS" - The interval in milliseconds to determine whether the queue target period above has been exceeded. Defaults to `1000`.

***Erlang VM configuration***

- "NODE_HOST" - The fully qualified host name of the current host.
- "ERLANG_COOKIE" - Magic cookie of the node.
- "REPLACE_OS_VARS" - An environment variable you export at runtime which instructed the tool to replace occurances of ${VAR} with the value from the system environment in the vm.args.

***Contract address configuration***
We allow a static configuration or a dynamic one, served as a http endpoint (one of them is mandatory).

- "ETHEREUM_NETWORK" - "RINKEBY" or "LOCALCHAIN".
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

- "ETHEREUM_NETWORK" - RINKEBY, ROPSTEN, MAINNET, or LOCALCHAIN
- "TXHASH_CONTRACT"
- "AUTHORITY_ADDRESS"
- "CONTRACT_ADDRESS_PLASMA_FRAMEWORK"
- "CONTRACT_ADDRESS_ETH_VAULT
- "CONTRACT_ADDRESS_ERC20_VAULT
- "CONTRACT_ADDRESS_PAYMENT_EXIT_GAME"

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
