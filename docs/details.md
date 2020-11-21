
**Table of Contents**

<!--ts-->
  * [elixir-omg applications](#elixir-omg-applications)
  * [Child chain server](#child-chain-server)
  * [Using the child chain server's API](#using-the-child-chain-servers-api)
    * [HTTP-RPC](#http-rpc)
  * [Ethereum private key management](#ethereum-private-key-management)
    * [geth](#geth)
  * [Managing the operator address](#managing-the-operator-address)
  * [Nonces restriction](#nonces-restriction)
  * [Funding the operator address](#funding-the-operator-address)
  * [Watcher and Watcher Info](#watcher-and-Watcher-info)
    * [Modes of the watcher](#modes-of-the-watcher)
    * [Using the watcher](#using-the-watcher)
    * [Endpoints](#endpoints)



## `elixir-omg` applications

`elixir-omg` is an umbrella app comprising of several Elixir applications:

The general idea of the apps responsibilities is:
  - `omg` - common application logic used by both the child chain server and watcher
  - `omg_bus` - an internal event bus to tie services together
  - `omg_child_chain` - child chain server
    - tracks Ethereum for things happening in the root chain contract (deposits/exits)
    - gathers transactions, decides on validity, forms blocks, persists
    - submits blocks to the root chain contract
    - see `apps/omg_child_chain/lib/omg_child_chain/application.ex` for a rundown of children processes involved
  - `omg_child_chain_rpc` - an HTTP-RPC server being the gateway to `omg_child_chain`
  - `omg_db` - wrapper around the child chain server's database to store the UTXO set and blocks necessary for state persistence
  - `omg_eth` - wrapper around the [Ethereum RPC client](https://github.com/exthereum/ethereumex)
  - `omg_status` - application monitoring facilities
  - `omg_utils` - various non-omg-specific shared code
  - `omg_watcher` - the [Watcher](#watcher-and-watcher-info)
  - `omg_watcher_info` - the [Watcher Info](#watcher-and-watcher-info)
  - `omg_watcher_rpc` - an HTTP-RPC server being the gateway to `omg_watcher`

See [application architecture](architecture.md) for more details.

## Child chain server

`:omg_child_chain` is the Elixir app which runs the child chain server, whose API is exposed by `:omg_child_chain_rpc`.

For the responsibilities and design of the child chain server see [Plasma Blockchain Design document](tesuji_blockchain_design.md).

## Using the child chain server's API

The child chain server is listening on port `9656` by default.

### HTTP-RPC

HTTP-RPC requests are served up on the port specified in `omg_child_chain_rpc`'s `config` (`:omg_child_chain_rpc, OMG.RPC.Web.Endpoint, http: [port: ...]`).
The available RPC calls are defined by `omg_child_chain` in `api.ex` - paths follow RPC convention e.g. `block.get`, `transaction.submit`.
All requests shall be POST with parameters provided in the request body in JSON object.
Object's properties names correspond to the names of parameters. Binary values shall be hex-encoded strings.

For API documentation see: https://developer.omisego.co/elixir-omg/.

## Ethereum private key management

### `geth`

Currently, the child chain server assumes that the authority account is unlocked or otherwise available on the Ethereum node.
This might change in the future.

## Managing the operator address

(a.k.a `authority address`)

The Ethereum address which the operator uses to submit blocks to the root chain is a special address which must be managed accordingly to ensure liveness and security.

## Nonces restriction

The [reorg protection mechanism](tesuji_blockchain_design.md#reorgs) enforces there to be a strict relation between the `submitBlock` transactions and block numbers.
Child block number `1000` uses Ethereum nonce `1`, child block number `2000` uses Ethereum nonce `2`, **always**.
This provides a simple mechanism to avoid submitted blocks getting reordered in the root chain.

This restriction is respected by the child chain server, whereby the Ethereum nonce is simply derived from the child block number.

As a consequence, the operator address must never send any other transactions, if it intends to continue submitting blocks.
(Workarounds to this limitation are available, if there's such requirement.)

**NOTE** Ethereum nonce `0` is necessary to call the `RootChain.init` function, which must be called by the operator address.
This means that the operator address must be a fresh address for every child chain brought to life.

## Funding the operator address

The address that is running the child chain server and submitting blocks needs to be funded with Ether.
At the current stage this is designed as a manual process, i.e. we assume that every **gas reserve checkpoint interval**, someone will ensure that **gas reserve** worth of Ether is available for transactions.

Gas reserve must be enough to cover the gas reserve checkpoint interval of submitting blocks, assuming the most pessimistic scenario of gas price.

Calculate the gas reserve as follows:

```
gas_reserve = child_blocks_per_day * days_in_interval * gas_per_submission * highest_gas_price
```
where
```
child_blocks_per_day = ethereum_blocks_per_day / submit_period
```

**Submit period** is the number of Ethereum blocks per a single child block submission) - configured in `:omg_child_chain, :child_block_submit_period`

**Highest gas price** is the maximum gas price which the operator allows for when trying to have the block submission mined (operator always tries to pay less than that maximum, but has to adapt to Ethereum traffic) - configured in (**TODO** when doing OMG-47 task)

**Example**

Assuming:
- submission of a child block every Ethereum block
- 15 second block interval on Ethereum, on average
- weekly cadence of funding, i.e. `days_in_interval == 7`
- allowing gas price up to 40 Gwei
- `gas_per_submission == 71505` (checked for `RootChain.sol` [at this revision](https://github.com/omisego/plasma-contracts/commit/50653d52169a01a7d7d0b9e2e4e3c4a4b904f128).
C.f. [here](https://rinkeby.etherscan.io/tx/0x1a79fdfa310f91625d93e25139e15299b4ab272ae504c56b5798a018f6f4dc7b))

we get
```
gas_reserve ~= (4 * 60 * 24 / 1) * 7 * 71505 * (40 / 10**9)  ~= 115 ETH
```

**NOTE** that the above calculation doesn't imply this is what is going to be used within a week, just a pessimistic scenario to calculate an adequate reserve.
If one assumes an _average_ gas price of 4 Gwei, the amount is immediately reduced to ~11.5 ETH weekly.

## Watcher and Watcher Info

The Watcher is an observing node that connects to Ethereum and the child chain server's API.
It ensures that the child chain is valid and notifies otherwise.
It exposes the information it gathers via an HTTP-RPC interface (driven by Phoenix).
It provides a secure proxy to the child chain server's API and to Ethereum, ensuring that sensitive requests are only sent to a valid chain.

For more on the responsibilities and design of the Watcher see [Plasma Blockchain Design document](tesuji_blockchain_design.md).

### Modes of the watcher

The watcher can be run in one of two modes:
  - **security-critical only**
    - intended to provide light-weight Watcher just to ensure security of funds deposited into the child chain
    - this mode will store all of the data required for security-critical operations (exiting, challenging, etc.)
    - it will not store data required for current and performant interacting with the child chain (spending, receiving tokens, etc.)
    - it will not expose some endpoints related to current and performant interacting with the child chain (`account.get_utxos`, `transaction.*`, etc.)
    - it will only require the `OMG.DB` key-value store database
    - this mode will prune all security-related data not necessary anymore for security reasons (from `OMG.DB`)
    - some requests to the API might be slow but must always work (called rarely in unhappy paths only, like mass exits)
  - **security-critical and informational API**
    - intended to provide convenient and performant API to the child chain data, on top of the security-related one
    - this mode will provide/store everything the **security-critical** mode does
    - this mode will store easily accessible register of all transactions _for a subset of addresses_ (currently, all addresses)
    - this mode will leverage the PostgreSQL - based `WatcherDB` database

In releases, `watcher` refers to the security-critical mode, while `watcher_info` refers to the security-critical and informational API mode.

### Using the watcher

The watcher is listening on port `7434` by default. And watcher info listens on port `7534`.

### Endpoints

For API documentation see: https://developer.omisego.co/elixir-omg/

### Ethereum private key management

Watcher doesn't hold or manage user's keys.
All signatures are assumed to be done outside.

# Configuration parameters

For docker deployments, and release deployments please refer to [Deployment Configuration](deployment_configuration.md).

**NOTE**: all margins are denominated in Ethereum blocks

## Generic configuration - `:omg` app

* **`deposit_finality_margin`** - the margin that is waited after a `DepositCreated` event in the root chain contract.
Only after this margin had passed:
  - the child chain will allow spending the deposit
  - the watcher and watcher info will consider a transaction spending this deposit a valid transaction

  It is important that for a given child chain, the child chain server and watchers use the same value of this margin.

  **NOTE**: This entry is defined in `omg`, despite not being accessed there, only in `omg_child_chain` and `omg_watcher`.
  The reason here is to minimize risk of Child Chain server's and Watcher's configuration entries diverging.

* **`ethereum_events_check_interval_ms`** - polling interval for pulling Ethereum events (logs) from the Ethereum client.

* **`coordinator_eth_height_check_interval_ms`** - polling interval for checking whether the root chain had progressed for the `RootChainCoordinator`.
Affects how quick the services reading Ethereum events realize there's a new block.

## Child chain server configuration - `:omg_child_chain` app

* **`submission_finality_margin`** - the margin waited before mined block submissions are purged from `BlockQueue`'s memory

* **`block_queue_eth_height_check_interval_ms`** - polling interval for checking whether the root chain had progressed for the `BlockQueue` exclusively

* **`fee_adapter_check_interval_ms`** - interval for checking fees updates from the fee adapter.
*
* **`fee_buffer_duration_ms`** - duration for which a fee is still valid after beeing updated.

* **`block_submit_every_nth`** - how many new Ethereum blocks must be mined, since previous submission **attempt**, before another block is going to be formed and submitted.

* **`block_submit_max_gas_price`** - the maximum gas price to use for block submission. The first block submission after application boot will use the max price,
  and gradually adjusts to the current optimum price for subsequent blocks.

* **`fee_specs_file_path`** - path to the file which defines fee requirements

* **`fee_adapter`** - is a tuple, where first element is a module name implementing `FeeAdapter` behaviour, e.g. `OMG.ChildChain.Fees.FileAdapter` and the second element is a Keyword `[opts: fee_adapter_opts]`
Options of the fee adapter, depends on adapter
  - **`specs_file_path`** - [FileAdaper only] path to file (including the file name) which defines fee requirements, see [fee_specs.json](fee_specs.json) for an example.
  - **`fee_feed_url`** - [FeedAdapter only] url to the fee service, that privides actual fees prices. Response should follow the file specs format.
  - **`fee_change_tolerance_percent`** - [FeedAdapter only!] positive integer describes significance of price change. When price in new reading changes above tolerance level, prices are updated immediately. Otherwise update interval is preserved.
  - **`stored_fee_update_interval_minutes`** - [FeedAdapter only!] positive integer describes time interval in minutes. The updates of token prices are carried out in update intervals as long as the changes are within tolerance.

## Watcher configuration - `:omg_watcher` app

* **`exit_processor_sla_margin`** - the margin to define the notion of a "late", invalid exit.
After this margin passes, every invalid exit is deemed a critical failure of the child chain (`unchallenged_exit`).
Such event will prompt a mass exit and stop processing new blocks.
See [exit validation documentation](docs/exit_validation.md) for details.
Cannot be larger than `min_exit_period_seconds` because otherwise it leads to a dangerous setup of the Watcher (in particular - muting the reports of unchallenged_exits).
Override using the `EXIT_PROCESSOR_SLA_MARGIN` system environment variable.

* **`exit_processor_sla_margin_forced`** - if set to `true`, will allow one to set a `exit_processor_sla_margin` that is larger than the `min_exit_period_seconds` of the child chain we're running for.
Set to `true` only when you know what you are doing.
Defaults to `false`, override using the `EXIT_PROCESSOR_SLA_MARGIN_FORCED` system environment variable.

* **`maximum_block_withholding_time_ms`** - for how long the Watcher will tolerate failures to get a submitted child chain block, before reporting a block withholding attack and stopping

* **`maximum_number_of_unapplied_blocks`** - the maximum number of downloaded and statelessly validated child chain blocks to hold in queue for applying

* **`exit_finality_margin`** - the margin waited before an exit-related event is considered final enough to pull and process

* **`block_getter_reorg_margin`** - the margin considered by `OMG.Watcher.BlockGetter` when searching for recent child chain block submission events.
This is driving the process of determining the height and particular event related to the submission of a particular child chain block

## `OMG.DB` configuration - `:omg_db` app

* **`path`** - path to the directory holding the LevelDB data store

* **`server_module`** - the module to use when talking to the `OMG.DB`

* **`server_name`** - the named process to refer to when talking to the `OMG.DB`

## `OMG.Eth` configuration - `:omg_eth` app

All binary entries are expected in hex-encoded, `0x`-prefixed.

* **`contract_addr`** - the address of the root chain contract

* **`authority_address`** - the address used by the operator to submit blocks

* **`txhash_contract`** - the Ethereum-transaction hash holding the deployment of the root chain contract

* **`eth_node`** - the Ethereum client which is used: `"geth" | "infura"`.

* **`child_block_interval`** - mirror of contract configuration `uint256 constant public CHILD_BLOCK_INTERVAL` from `RootChain.sol`

* **`min_exit_period_seconds`** - mirror of contract configuration `uint256 public minExitPeriod`

* **`ethereum_block_time_seconds`** - mirror the block time of the underlying root chain.
Defaults to 15 seconds, suitable for public networks (`mainnet` and testnets).
Override using the `ETHEREUM_BLOCK_TIME_SECONDS` system environment variable.
