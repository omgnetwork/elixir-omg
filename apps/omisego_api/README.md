# OmiseGO child chain server

**IMPORTANT NOTICE: Heavily WIP, expect anything**

`:omisego_api` is the Elixir app which runs the child chain server, whose API can be exposed by running `:omisego_jsonrpc` additionally.

For the responsibilities and design of the child chain server see [Tesuji Plasma Blockchain Design document](FIXME link pending).

## Setting up

1. Provide an Ethereum node connected to the appropriate network
1. Deploy `RootChain.sol` contract and prepare operator's authority address
1. Initialize the child chain database.
Do that with `mix run --no-start -e 'OmiseGO.DB.init()'`
1. Produce a configuration file with `omisego_eth` configured to the contract address, operator (authority) address and hash of contract-deploying transaction.
To do that use the template, filling it with details on the contract:

        use Mix.Config

        config :omisego_eth,
          contract_addr: "0x0",
          authority_addr: "0x0",
          txhash_contract: "0x0"

1. Start the child chain server, referencing the configuration file from the previous step with the JSON-RPC interface activated
  - `cd apps/omisego_jsonrpc`
  - `mix run --no-halt --config path/to/config.exs`

### Setting up (the developer's environment)

This is an example of how to quickly setup the developer's environment to run the child chain server.

1. For the Ethereum node: `geth --dev --dev.period 2 --rpc --rpcapi personal,web3,eth` gives a disposable private network
1. For the contract/authority address: (`mix run --no-start -e 'IO.inspect OmiseGO.Eth.DevHelpers.prepare_env!()'`)
1. Initialize child chain database normally.
**NOTE** It will use the default db path always (`~/.omisego/data`) so when running child chain and watcher side by side you need to configure more.
1. Configure `omisego_eth` normally, using data from `prepare_env!`.
    You can also shortcut with this little Elixir hocus-pocus:

          mix run --no-start -e \
            '
              OmiseGO.Eth.DevHelpers.prepare_env!
              |> OmiseGO.Eth.DevHelpers.create_conf_file
              |> IO.puts
            ' > your_config_file.exs

    The above lines:
      - create, fund and unlock the authority address
      - deploy the root chain contract
      - create the config file

    You'll need to pass the configuration file to `mix` invocations with `--config your_config_file.exs` flag

To play around with the child chain server, you can run an IEx REPL to gain access to helper functions: from `omisego` root dir do `iex -S mix run --no-start --config path/to/config.exs`.
In the REPL you can run commands mentioned in demos (see `docs/...`, don't pick `OBSOLETE` demos)

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
