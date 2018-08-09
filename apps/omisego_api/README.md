# OmiseGO child chain server

**IMPORTANT NOTICE: Heavily WIP, expect anything**

`:omisego_api` is the Elixir app which runs the child chain server, whose API can be exposed by running `:omisego_jsonrpc` additionally.

For the responsibilities and design of the child chain server see [Tesuji Plasma Blockchain Design document](FIXME link pending).

## Overview of apps

OmiseGO is an umbrella app comprising of several Elixir applications.
The apps listed below belong to the child chain server application, for Watcher-related apps see `apps/omisego_watcher/README.md`.

The general idea of the apps responsibilities is:
  - `omisego_api` - child chain server and main entrypoint to the functionality
    - tracks Ethereum for things happening in the root chain contract (deposits/exits)
    - gathers transactions, decides on validity, forms blocks, persists
    - submits blocks to the root chain contract
    - see `lib/api/application.ex` for a rundown of children processes involved
  - `omisego_db` - wrapper around the child chain server's database to store the UTXO set and blocks necessary for state persistence
  - `omisego_eth` - wrapper around the [Ethereum RPC client](https://github.com/exthereum/ethereumex)
  - `omisego_jsonrpc` - a JSONRPC 2.0 server being the gateway to `omisego_api`
  - `omisego_performance` - performance tester for the child chain server

## General setup
For specific instructions on setting up a developer environment, jump to the next section.

1. Follow the high-level **Setting up** from [here](../../README.md)
1. Start the child chain server, referencing the configuration file from the previous step with the JSON-RPC interface activated

        cd apps/omisego_jsonrpc
        mix run --no-halt --config path/to/config.exs


## Setting up (a developer environment)
### Start up developer instance of Ethereum
The easiest way to get started is if you have access to a developer instance of `geth`. If you don't already have access to a developer instance of `geth`, follow the [installation](../../docs/install.md) instructions.

A developer instance of geth runs Ethereum locally and prefunds an account. However, when `geth` terminates, the state of the Ethereum network is lost.

```
geth --dev --dev.period 1 --rpc --rpcapi personal,web3,eth
```

### Persistent developer instance
Alternatively, a persistent developer instance that does not lose state can be started with the following command:
```
geth --dev --dev.period 1 --rpc --rpcapi personal,web3,eth  --datadir ~/.geth --ipc
```

After `geth` is restarted with the above command, the authority account must be unlocked

```
geth attach http://127.0.0.1:8545
personal.unlockAccount(“<authority_addr from ~/config.exs>”, '', 0)
```

### Configure the `omisego_eth` app

The following step will:
- create, fund and unlock the authority address
- deploy the root chain contract
- create the config file

 deploy the root chain contract and configure your app:
Note that `geth` needs to already be running for this step to work!
```
mix compile && mix run --no-start -e \
 '
   OmiseGO.Eth.DevHelpers.prepare_env!
   |> OmiseGO.Eth.DevHelpers.create_conf_file
   |> IO.puts
 ' > ~/config.exs
```

The result should look something like this (use `cat ~/config.exs` to check):
```
use Mix.Config
config :omisego_eth,
  contract_addr: "0x005f49af1af9eee6da214e768683e1cc8ab222ac",
  txhash_contract: "0x3afd2c1b48eaa3100823de1924d42bd48ee25db1fd497998158f903b6a841e92",
  authority_addr: "0x5c1a5e5d94067c51ec51c6c00416da56aac6b9a3"
```
The above values are only demonstrative, **do not** copy and paste!

Note that you'll need to pass the configuration file each time you run `mix` with the following parameter `--config ~/config.exs` flag

### Initialize the child chain database
Initialize the database with the following command:
```
mix run --no-start -e 'OmiseGO.DB.init()'
```

### Start it up!
* Start up geth if not already started.
* Start Up the child chain server

```
cd omisego/apps/omisego_jsonrpc
mix run --no-halt --config ~/config.exs
```

### Follow the demos
After starting the child chain server as above, you may follow the steps the demo scripts. Note that some steps should be performed in the Elixir shell (iex) and some in the shell directly.

From the `omisego` root directory:
```
iex -S mix run --no-start --config ~/config.exs
```

Follow one of the scripts in the [docs](../../docs) directory. Don't pick any `OBSOLETE` demos.

## Using the child chain server's API

### JSONRPC 2.0

JSONRPC 2.0 requests are served up on the port specified in `omisego_jsonrpc`'s `config` (`9656` by default).
The available RPC calls are defined by `omisego_api` in `api.ex` - the functions are `method` names and their respective arguments must be sent in a `params` dictionary.
The argument names are indicated by the `@spec` clauses.

#### `submit`

##### Request

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

##### Response

```json
{
    "id": 0,
    "jsonrpc": "2.0",
    "result": {
        "blknum": 995000,
        "tx_hash": "tx hash in hex",
        "tx_index": 0
    }
}
```

#### `get_block`

##### Request

```json
{
  "params":{
    "hash":"block hash in hex"
  },
  "method":"get_block",
  "jsonrpc":"2.0",
  "id":0
}
```

##### Response

```json
{
    "id": 0,
    "jsonrpc": "2.0",
    "result": {
        "hash": "block hash in hex",
        "transactions": [
            "transaction bytes in hex",
            "..."
        ]
    }
}
```

### Websockets

**TODO** consider if we want to expose at all

## Running a child chain in practice

**TODO** other sections

### Funding the operator address

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
**Submit period** is the number of Ethereum blocks per a single child block submission) - configured in `:omisego_api, :child_block_submit_period`

**Highest gas price** is the maximum gas price which the operator allows for when trying to have the block submission mined (operator always tries to pay less than that maximum, but has to adapt to Ethereum traffic) - configured in (**TODO** when doing OMG-47 task)

#### Example

Assuming:
- submission of a child block every Ethereum block
- weekly cadence of funding
- highest gas price 40 Gwei
- 75071 gas per submission (checked for `RootChain.sol` used  [at this revision](https://github.com/omisego/omisego/commit/21dfb32fae82a59824aa19bbe7db87ecf33ecd04))

we get
```
gas_reserve ~= 4 * 60 * 24 / 1 * 7 * 75071 * 40 / 10**9  ~= 121 ETH
```
