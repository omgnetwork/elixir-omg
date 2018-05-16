# OmiseGO child chain server

`:omisego_api` is the Elixir app which runs the child chain server, whose API can be exposed by running `:omisego_jsonrpc` additionally.

For the responsibilities and design of the child chain server see [Tesuji Plasma Blockchain Design document](FIXME link pending).

## Running the child chain server as operator

### Setting up

1. Provide an Ethereum node (e.g. `geth --dev --rpc` for a disposable developer's private network).
2. Deploy `RootChain.sol` contract (**FIXME** settle for a developer's tool to do that - currently we have more than one)
3. Initialize the child chain database (**FIXME** how? this is being changed now, should adapt)
4. Configure `omisego_eth` with contract address, operator (authority) address and hash of contract-deploying transaction (see `omisego_eth/config/config.exs`) (**FIXME** how? this is being changed now, should adapt)

### Starting the child chain server

  - `mix run`
  - or `iex -S mix` then in the `iex` REPL you can run commands mentioned in demos (see `docs/...`, don't pick `OBSOLETE` demos)
    FIXME: update that demo?

### Funding the operator address

The address that is running the child chain server and submitting blocks needs to be funded with ether.
At current stage this is designed as a manual process, i.e. we assume that every **gas reserve checkpoint interval**, someone will ensure that **gas reserve** worth of ether is accessible for transactions.

Gas reserve must be enough to cover gas reserve checkpoint interval of submitting blocks, assuming the most pessimistic scenario of gas price.

Calculate as follows:

```
gas_reserve = child_blocks_per_day * days_in_interval * gas_per_submission * highest_gas_price
```
where
```
child_blocks_per_day = ethereum_blocks_per_day / submit_period
```
**Submit period** is the number of Ethereum blocks per a single child block submission) - configured in `:omisego_api, :child_block_submit_period`
**Highest gas price** is the maximum gas price which operator allows when trying to have the block submission mined (operator always tries to pay less than that maximum, but has to adapt to Ethereum traffic) - configured in (**TODO** when doing [OMG-47](https://www.pivotaltracker.com/story/show/156037267))

#### Example

Assuming:
- submitting a child block every Ethereum block
- weekly cadence of funding
- highest gas price 40 Gwei
- 75071 gas per submission (checked for `RootChain.sol` used  [at this revision](https://github.com/omisego/omisego/commit/21dfb32fae82a59824aa19bbe7db87ecf33ecd04))

we get
```
gas_reserve ~= 4 * 60 * 24 / 1 * 7 * 75071 * 40 / 10**9  ~= 121 ETH
```

## Using the child chain server's API

### JSONRPC 2.0

JSONRPC 2.0 requests are listened on on the port specified in `omisego_jsonrpc`'s `config`.
The available RPC calls are defined by `omisego_api` in `api.ex` - the functions are `method` names and their respective arguments make the dictionary sent as `params`.
The argument names are indicated by the `@spec` clauses.

#### `submit`

```json
{
  "params":{
    "transaction":"rlp encoded plasma transaction in hex"
  },
  "method":"submit",
  "jsonrpc":"2.0",
  "id":0
}
```

#### `get_block`

```json
{
  "params":{
    "hash":"5A747C1AB90FEC15BD1D95FDFEB9B23D652BA043F7841AF114BBB7F39488B510"
  },
  "method":"get_block",
  "jsonrpc":"2.0",
  "id":0
}
```

### Websockets

**TODO** consider if we want to expose at all

## Overview of apps

OmiseGO is an umbrella app comprising several Elixir applications.
Apps listed below belong to the child chain server application, for Watcher-related apps see `apps/omisego_watcher/README.md`.

The general idea of the apps responsibilities is:
  - `omisego_api` - child chain server and main entrypoint to the functionality
    - tracks Ethereum for things happening in the root chain contract (deposits/exits)
    - gathers transactions, decides on validity, forms blocks, persists
    - submits blocks to the root chain contract
  - `omisego_db` - wrapper around the child chain server's database to store the UTXO set and blocks necessary for state persistence
  - `omisego_eth` - wrapper around the [Ethereum RPC client](https://github.com/exthereum/ethereumex)
  - `omisego_jsonrpc` - a JSONRPC 2.0 server being the gateway to `omisego_api`
  - `omisego_performance` - performance tester for the child chain server
