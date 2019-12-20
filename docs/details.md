
**Table of Contents**

<!--ts-->
   * [elixir-omg applications](#elixir-omg-applications)
      * [Child chain server](#child-chain-server)
         * [Using the child chain server's API](#using-the-child-chain-servers-api)
            * [HTTP-RPC](#http-rpc)
         * [Running a child chain in practice](#running-a-child-chain-in-practice)
            * [Ethereum private key management](#ethereum-private-key-management)
               * [geth](#geth)
               * [parity](#parity)
            * [Specifying the fees required](#specifying-the-fees-required)
            * [Managing the operator address](#managing-the-operator-address)
               * [Nonces restriction](#nonces-restriction)
               * [Funding the operator address](#funding-the-operator-address)
      * [Watcher](#watcher)
         * [Modes of the watcher](#modes-of-the-watcher)
         * [Using the watcher](#using-the-watcher)
         * [Endpoints](#endpoints)
         * [Ethereum private key management](#ethereum-private-key-management-1)


# `elixir-omg` applications

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
  - `omg_performance` - performance tester for the child chain server
  - `omg_status` - application monitoring facilities
  - `omg_utils` - various non-omg-specific shared code
  - `omg_watcher` - the [Watcher](#watcher)
  - `omg_watcher_info` - the [Watcher Info](#watcher)
  - `omg_watcher_rpc` - an HTTP-RPC server being the gateway to `omg_watcher`

See [application architecture](docs/architecture.md) for more details.

## Child chain server

`:omg_child_chain` is the Elixir app which runs the child chain server, whose API is exposed by `:omg_child_chain_rpc`.

For the responsibilities and design of the child chain server see [Tesuji Plasma Blockchain Design document](docs/tesuji_blockchain_design.md).

### Using the child chain server's API

The child chain server is listening on port `9656` by default.

#### HTTP-RPC

HTTP-RPC requests are served up on the port specified in `omg_child_chain_rpc`'s `config` (`:omg_child_chain_rpc, OMG.RPC.Web.Endpoint, http: [port: ...]`).
The available RPC calls are defined by `omg_child_chain` in `api.ex` - paths follow RPC convention e.g. `block.get`, `transaction.submit`.
All requests shall be POST with parameters provided in the request body in JSON object.
Object's properties names correspond to the names of parameters. Binary values shall be hex-encoded strings.

For API documentation see: https://omisego.github.io/elixir-omg.

# Ethereum private key management

## `geth`

Currently, the child chain server assumes that the authority account is unlocked or otherwise available on the Ethereum node.
This might change in the future.

## Managing the operator address

(a.k.a `authority address`)

The Ethereum address which the operator uses to submit blocks to the root chain is a special address which must be managed accordingly to ensure liveness and security.

## Nonces restriction

The [reorg protection mechanism](docs/tesuji_blockchain_design.md#reorgs) enforces there to be a strict relation between the `submitBlock` transactions and block numbers.
Child block number `1000` uses Ethereum nonce `1`, child block number `2000` uses Ethereum nonce `2`, **always**.
This provides a simple mechanism to avoid submitted blocks getting reordered in the root chain.

This restriction is respected by the child chain server (`OMG.ChildChain.BlockQueue`), whereby the Ethereum nonce is simply derived from the child block number.

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

For more on the responsibilities and design of the Watcher see [Tesuji Plasma Blockchain Design document](docs/tesuji_blockchain_design.md).

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
    - this mode will leverage the Postgres-based `WatcherDB` database

In releases, `watcher` refers to the security-critical mode, while `watcher_info` refers to the security-critical and informational API mode.

### Using the watcher

The watcher is listening on port `7434` by default. And watcher info listens on port `7534`.

### Endpoints

For API documentation see: https://omisego.github.io/elixir-omg

### Ethereum private key management

Watcher doesn't hold or manage user's keys.
All signatures are assumed to be done outside.
A planned exception may be to allow Watcher to sign challenges, but using a non-sensitive/low-funded Ethereum account.
