# Architecture

This is a high-level rundown of the architecture of the `OmiseGO` apps.

The below diagram demonstrates the various pieces and where this umbrella app fits in.
![high level architecture overview diagram](assets/architecture_overview.jpg)
**NOTE** only use the high-level diagram to get a vague idea, meaning of boxes/arrows may be imprecise.

## Interactions

**[Diagram](https://docs.google.com/drawings/d/11ugr_VQzqh0afU6NPpHW893jww182POaGE3sYhgm9Gw/edit?usp=sharing)** illustrates the interactions described below.

This lists only interactions between the different processes that build up both the Child Chain Server and Watcher.
For responsibilities of the processes/modules look into respective docs in `.ex` files.

**NOTE**:
- for `OmiseGO.API` modules/processes look in `apps/omisego_api`
- for `OmiseGOWatcher` modules/processes look in `apps/omisego_watcher`
- for `OmiseGO.Eth` look in `apps/omisego_eth`
- for `OmiseGO.DB` look in `apps/omisego_db`
- for `OmiseGO.Performance` look in `apps/omisego_performance`
- for `OmiseGO.JSONRPC` look in `apps/omisego_jsonrpc`

**NOTE 2** The hexagonal shape hints towards component being a wrapper (port/adapter) to something external, versus rectangular shape being an internal component.

### `OmiseGO.API.State`

- writes blocks and UTXO set to `OmiseGO.DB`
- pushes freshly formed blocks to `OmiseGO.API.FreshBlocks`

### `OmiseGO.API`

- accepts child chain transactions, decodes, stateless-validates and executes on `OmiseGO.API.State`
- forwards `get_block` requests to `OmiseGO.API.FreshBlocks`

### `OmiseGO.API.FreshBlocks`

- reverts to reading `OmiseGO.DB` for old blocks

### `OmiseGO.RootChainCoordinator`

- reads Ethereum block height from `OmiseGO.Eth`
- synchronizes view of Ethereum block height of all enrolled processes (see other processes descriptions)

### `:exiter`

Actually `OmiseGO.API.EthereumEventListener` setup with `:exiter`.

- pushes exits to `OmiseGO.API.State` on child chain server's side
- tracks exits via `OmiseGO.API.RootChainCoordinator`

### `:depositor`

Actually `OmiseGO.API.EthereumEventListener` setup with `:depositor`.

- pushes deposits to `OmiseGO.API.State`
- tracks deposits via `OmiseGO.API.RootChainCoordinator`

### `OmiseGO.API.BlockQueue`

- requests `form_block` on `OmiseGO.API.State` and takes block hashes in return
- tracks Ethereum height and child chain block submission mining via `OmiseGO.Eth` and `OmiseGO.API.RootChainCoordinator`

### `OmiseGO.API.FeeChecker`
- `OmiseGO.API` calls it to get acceptable currencies and actual fee amounts to validate transactions

### `OmiseGOWatcher.BlockGetter`

- tracks child chain blocks via `OmiseGO.API.RootChainCoordinator`
- manages concurrent `Task`'s to pull blocks from child chain server API (JSON-RPC)
- pushes decoded and statelessly valid blocks to `OmiseGO.API.State`
- pushes statefully valid blocks and transactions (acknowledged by `OmiseGO.API.State` above) to `WatcherDB`
- emits block, transaction, consensus events to `OmiseGOWatcher.Eventer`

### `OmiseGOWatcher.ExitValidator` (fast)

TODO - possible requires sorting out of this vs `:exiter`

### `OmiseGOWatcher.ExitValidator` (slow)

TODO

### `Phoenix app` (not a module - section name TODO)

- uses data stored in the `WatcherDB` to server user's requests
- subscribes to event buses to `OmiseGOWatcher.Eventer`

### `OmiseGOWatcher.Eventer`

- pushes events to `Phoenix app`

### `OmiseGO.JSONRPC`

- exposes `OmiseGO.API` via a `cowboy`-driven JSON-RPC2 interface

### `OmiseGO.Performance`

- executes requests to `OmiseGO.JSONRPC`
- forces block forming by talking directly to `OmiseGO.API.State`

## Databases

The confusing (and to be probably amended in the future) part is that we have two databases

### `OmiseGO.DB`

An "intimate" database for `OmiseGO.API.State` that holds the UTXO set and blocks.
May be seen and read by other processes to sync on the persisted state of `OmiseGO.API.State` and UTXO set by consequence.

Non-relational data, so we're having a simple KV for this.

Implemented with `leveldb` via `ExlevelDB`, possibly to be swapped out for anything better in the future.
Each instance of either Child Chain Server or Watcher should have it's own instance.

Database necessary to properly ensure validity and availability of blocks and transactions

- it is read by `OmiseGO.API.State` to discover the UTXO set on restart
- it is read by many other processes to discover where they left off, on restart

### `WatcherDB` (TODO - name? there is no such module as `WatcherDB`)

A convenience database running alongside the Watcher **only**.
Holds all information necessary to manage the funds held:
- UTXOs owned by user's particular address(es)
- all transactions to be able to challenge
- transaction history

Relational data, to be able to navigate through the transactions and UTXOs.

Implemented with Postgres (SQLite for test runs).
This database might be shared between Watchers, e.g. when it pertains to a single wallet provider running multiple `eWallet` instances for scaling.
