<img src="docs/assets/logo.png" align="right" />

The `elixir-omg` repository contains OmiseGO's Elixir implementation of Plasma and forms the basis for the OMG Network.

[![Build Status](https://jenkins.omisego.io/buildStatus/icon?job=omisego/elixir-omg/develop)](https://jenkins.omisego.io/blue/organizations/jenkins/omisego%2Felixir-omg/activity?branch=develop) [![Coverage Status](https://coveralls.io/repos/github/omisego/elixir-omg/badge.svg?branch=develop)](https://coveralls.io/github/omisego/elixir-omg?branch=develop) [![Gitter chat](https://badges.gitter.im/omisego/elixir-omg.png)](https://gitter.im/omisego/elixir-omg)

**IMPORTANT NOTICE: Heavily WIP, expect anything**

**Table of Contents**

<!--ts-->
   * [Getting Started](#getting-started)
      * [Install](#install)
      * [Setup](#setup)
         * [Setting up a child chain server (a developer environment)](#setting-up-a-child-chain-server-a-developer-environment)
            * [Start up developer instance of Ethereum](#start-up-developer-instance-of-ethereum)
               * [Persistent developer geth instance](#persistent-developer-geth-instance)
            * [Configure the omg_eth app](#configure-the-omg_eth-app)
            * [Initialize the child chain database](#initialize-the-child-chain-database)
            * [Start it up!](#start-it-up)
         * [Setting up a Watcher (a developer environment)](#setting-up-a-watcher-a-developer-environment)
            * [Configure the PostgreSQL server with:](#configure-the-postgresql-server-with)
            * [Configure the Watcher](#configure-the-watcher)
            * [Initialize the Watcher's databases](#initialize-the-watchers-databases)
            * [Start the Watcher](#start-the-watcher)
         * [Follow the demos](#follow-the-demos)
      * [Troubleshooting](#troubleshooting)
   * [elixir-omg applications](#elixir-omg-applications)
      * [Child chain server](#child-chain-server)
         * [Using the child chain server's API](#using-the-child-chain-servers-api)
            * [JSONRPC 2.0](#jsonrpc-20)
               * [submit](#submit)
               * [get_block](#get_block)
         * [Running a child chain in practice](#running-a-child-chain-in-practice)
            * [Funding the operator address](#funding-the-operator-address)
      * [Watcher](#watcher)
         * [Using the watcher](#using-the-watcher)
         * [Endpoints](#endpoints)
         * [Websockets](#websockets)
            * [transfer:ethereum_address](#transferethereum_address)
            * [spends:ethereum_address](#spendsethereum_address)
            * [receives:ethereum_address](#receivesethereum_address)
            * [byzantine_invalid_exit](#byzantine_invalid_exit)
            * [byzantine_bad_chain](#byzantine_bad_chain)
            * [TODO block](#todo-block)
            * [TODO deposit_spendable](#todo-deposit_spendable)
            * [TODO fees](#todo-fees)
      * [Contracts](#contracts)
         * [Installing dependencies and compiling contracts](#installing-dependencies-and-compiling-contracts)
   * [Testing &amp; development](#testing--development)

<!-- Added by: user, at: 2018-08-23T17:54+02:00 -->

<!--te-->

<!-- Created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc) -->
<!-- .gh-md-toc --insert README.md -->

The first release of the OMG Network is based upon **Tesuji Plasma**, an iterative design step over [Plasma MVP](https://github.com/omisego/plasma-mvp). The diagram below illustrates the relationship between the wallet provider and how wallet providers connect to **Tesuji Plasma**.

![eWallet server and OMG Network](docs/assets/OMG-network-eWallet.jpg)

See the [Tesuji Plasma design document](docs/tesuji_blockchain_design.md) for a full description for the Child Chain Server and Watcher.
**NOTE** not all parts of that design have been implemented!

# Getting Started

A public testnet for the OMG Network is not yet available. However, if you are brave and want to test being a Tesuji Plasma chain operator, read on!

## Install
Firstly, **[install](docs/install.md)** the child chain server and watcher.

## Setup
The setup process for the Child chain server and for the Watcher is similar.
A high level flow of the setup for both is outlined below.

**NOTE** If you are more interested in just getting things running quickly or unfamiliar with [Elixir and Mix](https://elixir-lang.org/), skip the outline and scroll down to the next sections for step-by-step instructions.

1. Run an Ethereum node connected to the appropriate network and make sure it's ready to use
    - currently only connections via RPC over HTTP are supported, defaulting to `http://localhost:8545`.
    To customize that, configure `ethereumex`, with `url: "http://host:port"`
    - `Byzantium` is required to be in effect
1. (**Child chain server only**) Prepare the authority address and deploy `RootChain.sol`, see [Contracts section](#contracts).
**Authority address** belongs to the child chain operator, and is used to run the child chain (submit blocks to the root chain contract)
1. Produce a configuration file for `omg_eth` with the contract address, authority address and hash of contract-deploying transaction.
The configuration keys can be looked up at [`apps/omg_eth/config/config.exs`](apps/omg_eth/config/config.exs).
Such configuration must become part of the [Mix configuration](https://hexdocs.pm/mix/Mix.Config.html) for the app you're going to be running.
1. Initialize the child chain server's `OMG.DB` database.
1. At this point the child chain server should be properly setup to run by starting the `omg_api` Mix app
1. (**Watcher only**) Configure PostgreSQL for `WatcherDB` database
1. (**Watcher only**) Acquire the configuration file with root chain deployment data
1. (**Watcher only**, optional) If running on the same machine as the child chain server, customize the location of `OMG.DB` database folder
1. (**Watcher only**) Configure the child chain url (default is `http://localhost:9656`) by configuring `:omg_jsonrpc` with `child_chain_url: "http://host:port"`
1. (**Watcher only**) Initialize the Watcher's `OMG.DB` database
1. (**Watcher only**) Create and migrate the PostgreSQL `WatcherDB` database
1. (**Watcher only**) At this point the Watcher should be properly setup to run by starting the `omg_watcher` Mix app

### Setting up a child chain server (a developer environment)
#### Start up developer instance of Ethereum
The easiest way to get started is if you have access to a developer instance of `geth`.
If you don't already have access to a developer instance of `geth`, follow the [installation](docs/install.md) instructions.

A developer instance of `geth` runs Ethereum locally and prefunds an account.
However, when `geth` terminates, the state of the Ethereum network is lost.

```
geth --dev --dev.period 1 --rpc --rpcapi personal,web3,eth,net  --rpcaddr 0.0.0.0
```

##### Persistent developer `geth` instance
Alternatively, a persistent developer instance that does not lose state can be started with the following command:
```
geth --dev --dev.period 1 --rpc --rpcapi personal,web3,eth,net  --rpcaddr 0.0.0.0 --datadir ~/.geth
```

#### Prepare and configure the root chain contract

The following step will:
- create, fund and unlock the authority address
- deploy the root chain contract
- create the config file

Note that `geth` needs to already be running for this step to work!

From the root dir of `elixir-omg`:
```
mix compile
mix run --no-start -e \
 '
   contents = OMG.Eth.DevHelpers.prepare_env!() |> OMG.Eth.DevHelpers.create_conf_file()
   "~/config.exs" |> Path.expand() |> File.write!(contents)
 '
```

The result should look something like this (use `cat ~/config.exs` to check):
```
use Mix.Config
config :omg_eth,
  contract_addr: "0x005f49af1af9eee6da214e768683e1cc8ab222ac",
  txhash_contract: "0x3afd2c1b48eaa3100823de1924d42bd48ee25db1fd497998158f903b6a841e92",
  authority_addr: "0x5c1a5e5d94067c51ec51c6c00416da56aac6b9a3"
```
The above values are only demonstrative, **do not** copy and paste!

Note that you'll need to pass the configuration file each time you run `mix` with the following parameter `--config ~/config.exs` flag

**NOTE** If you're using persistent `geth` and `geth` is restarted after the above step, the authority account must be unlocked again:

```
geth attach http://127.0.0.1:8545
personal.unlockAccount(“<authority_addr from ~/config.exs>”, '', 0)
```

#### Initialize the child chain database
Initialize the database with the following command.
**CAUTION** This wipes the old data clean!:
```
rm -rf ~/.omg/data
mix run --no-start -e 'OMG.DB.init()'
```

The database files are put at the default location `~/.omg/data`.
You need to re-initialize the database, in case you want to start a new child chain from scratch!

#### Start it up!
* Start up geth if not already started.
* Start Up the child chain server:

```
cd apps/omg_api
iex -S mix run --config ~/config.exs
```

### Setting up a Watcher (a developer environment)

This assumes that you've got a developer environment Child chain server set up and running on the default `localhost:9656`, see above.

#### Configure the PostgreSQL server with:

```
sudo -u postgres createuser omisego_dev
sudo -u postgres psql
alter user omisego_dev with encrypted password 'omisego_dev';
ALTER USER omisego_dev CREATEDB;
```

#### Configure the Watcher

Copy the configuration file used by the Child chain server to `~/config_watcher.exs`

```
cp ~/config.exs ~/config_watcher.exs
```

You need to use a **different** location of the `OMG.DB` for the Watcher, so in `~/config_watcher.exs` append the following:

```
config :omg_db,
  leveldb_path: Path.join([System.get_env("HOME"), ".omg/data_watcher"])
```

#### Initialize the Watcher's databases

**CAUTION** This wipes the old data clean!

```
rm -rf ~/.omg/data_watcher
cd apps/omg_watcher
mix do ecto.reset --no-start, run --no-start -e 'OMG.DB.init()' --config ~/config_watcher.exs
```

#### Start the Watcher

To start syncing to the Child chain server (continue from the `apps/omg_watcher` directory):

```
iex -S mix run --config ~/config_watcher.exs
```

### Follow the demos
After starting the child chain server and/or Watcher as above, you may follow the steps in the demo scripts.
Note that some steps should be performed in the Elixir shell (iex) and some in the shell directly.

To start a configured instance of the `iex` REPL, from the `elixir-omg` root directory do:
```
iex -S mix run --no-start --config ~/config.exs
```

Follow one of the scripts in the [docs](docs/) directory. Don't pick any `OBSOLETE` demos.

## Troubleshooting
Solutions to common problems may be found in the [troubleshooting](docs/troubleshooting.md) document.

# `elixir-omg` applications

`elixir-omg` is an umbrella app comprising of several Elixir applications:

The general idea of the apps responsibilities is:
  - `omg_api` - child chain server
    - tracks Ethereum for things happening in the root chain contract (deposits/exits)
    - gathers transactions, decides on validity, forms blocks, persists
    - submits blocks to the root chain contract
    - see `lib/api/application.ex` for a rundown of children processes involved
  - `omg_db` - wrapper around the child chain server's database to store the UTXO set and blocks necessary for state persistence
  - `omg_eth` - wrapper around the [Ethereum RPC client](https://github.com/exthereum/ethereumex)
  - `omg_jsonrpc` - a JSONRPC 2.0 server being the gateway to `omg_api`
  - `omg_performance` - performance tester for the child chain server
  - `omg_watcher` - Phoenix app that runs the Watcher

See [application architecture](docs/architecture.md) for more details.

## Child chain server

`:omg_api` is the Elixir app which runs the child chain server, whose API is exposed by `:omg_jsonrpc`.

For the responsibilities and design of the child chain server see [Tesuji Plasma Blockchain Design document](docs/tesuji_blockchain_design.md).

### Using the child chain server's API

#### JSONRPC 2.0

JSONRPC 2.0 requests are served up on the port specified in `omg_jsonrpc`'s `config` (`9656` by default).
The available RPC calls are defined by `omg_api` in `api.ex` - the functions are `method` names and their respective arguments must be sent in a `params` dictionary.
The argument names are indicated by the `@spec` clauses.

##### `submit`

Request:

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

See the [step by step transaction generation specs here](docs/tesuji_tx_integration.md).

Response:

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

##### `get_block`

Request:

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

Response:

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

### Running a child chain in practice

**TODO** other sections

#### Funding the operator address

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
**Submit period** is the number of Ethereum blocks per a single child block submission) - configured in `:omg_api, :child_block_submit_period`

**Highest gas price** is the maximum gas price which the operator allows for when trying to have the block submission mined (operator always tries to pay less than that maximum, but has to adapt to Ethereum traffic) - configured in (**TODO** when doing OMG-47 task)

**Example**

Assuming:
- submission of a child block every Ethereum block
- weekly cadence of funding
- highest gas price 40 Gwei
- 75071 gas per submission (checked for `RootChain.sol` used  [at this revision](https://github.com/omisego/omisego/commit/21dfb32fae82a59824aa19bbe7db87ecf33ecd04))

we get
```
gas_reserve ~= 4 * 60 * 24 / 1 * 7 * 75071 * 40 / 10**9  ~= 121 ETH
```

## Watcher

The Watcher is an observing node that connects to Ethereum and the child chain server's API.
It ensures that the child chain is valid and notifies otherwise.
It exposes the information it gathers via a REST interface (Phoenix).
It provides a secure proxy to the child chain server's API and to Ethereum, ensuring that sensitive requests are only sent to a valid chain.

For more on the responsibilities and design of the Watcher see [Tesuji Plasma Blockchain Design document](docs/tesuji_blockchain_design.md).

### Using the watcher

### Endpoints
TODO

### Websockets

Exposed websockets are using [Phoenix channels](https://hexdocs.pm/phoenix/channels.html) feature.
Different events are emitted for each topic.

There are the following topics:

#### transfer:ethereum_address

Events:

**address_received and address_spent**

`address_received` event informing about that particular address received funds.

`address_spent` event informing about that particular address spent funds.

Blocks are validated by the Watcher after a short (not-easily-configurable) finality margin. By consequence, above events will be emitted no earlier than that finality margin.
In case extra finality is required for high-stakes transactions, the client is free to wait any number of Ethereum blocks (confirmations) on top of submitted_at_ethheight

```json
{
  "topic": "transfer:0xfd5374cd3fe7ba8626b173a1ca1db68696ff3692",
  "ref": null,
  "payload": {
    "child_blknum": 10000,
    "child_block_hash": "DB32876CC6F26E96B9291682F3AF4A04C2AA2269747839F14F1A8C529CF90225",
    "submited_at_ethheight": 14,
    "tx": {
      "signed_tx": {
        "raw_tx": {
          "amount1": 7,
          "amount2": 3,
          "blknum1": 2001,
          "blknum2": 0,
          "cur12": "0000000000000000000000000000000000000000",
          "newowner1": "051902B7A7D6DCB915CE8FFD3BF46B5E0E16BB9C",
          "newowner2": "E6E3F1307219F68AE4B271CFD493EC8F932C34D9",
          "oindex1": 0,
          "oindex2": 0,
          "txindex1": 0,
          "txindex2": 0
        },
        "sig1": "7B52AB ...",
        "sig2": "2ABGAT ...",
        "signed_tx_bytes": "F8CF83 ..."
      },
      "signed_tx_hash": "0768DC526A093C8C058303832FF3AB45893466D731A34BCF1BF2F866586C0FE6",
      "spender1": "6DCB915C051902B7A7DE8FFD3BF46B5E0E16BB9C",
      "spender2": "5E0E16BB9C19F68AE4B271CFD493EC8F932C34D9"
    }
  },
  "join_ref": null,
  "event": "address_received"
}
```

**TODO** the rest of the events' specs. First draft:

#### spends:ethereum_address

Events:

**address_spent**

#### receives:ethereum_address

Events:

**address_received**

#### byzantine_invalid_exit

Events:

**in_flight_exit**

**piggyback**

**exit_from_spent**

#### byzantine_bad_chain

Events:

**invalid_block**

Event informing about that particular block is invalid.

**block_withholding**

Event informing about that the child chain is withholding block.

**invalid_fee_exit**

#### TODO block

#### TODO deposit_spendable

#### TODO fees

Events:

**fees_exited**

## Contracts

OMG network uses contract code from [the contracts repo](http://github.com/omisego/plasma-contracts).
Code from a particular branch in that repo is used, see [one of `mix.exs` configuration files](apps/omg_eth/mix.exs) for details.

Contract code is downloaded automatically when getting dependencies of the Mix application with `mix deps.get`.
You can find the downloaded version of that code under `deps/plasma_contracts`.

### Installing dependencies and compiling contracts

**Python3 is required**, [`virtualenv`](https://virtualenv.pypa.io/en/stable/) is recommended.

To install dependencies:
```bash
sudo apt-get install libssl-dev solc
pip install -r contracts/requirements.txt
```

Contracts will compile automatically as a regular mix dependency.
To compile contracts manually:
```
mix deps.compile plasma_contracts
```

**DEV NOTE** `requirements.txt` is the frozen set of versioned dependencies, effect of running
```bash
pip install -r requirements-to-freeze.txt && pip freeze | grep -v ^pkg-resources > requirements.txt
```
see [a better pip workflow^TM here](https://www.kennethreitz.org/essays/a-better-pip-workflow) for rationale.

**DEV NOTE** removing `pkg-resources` comes from [here](https://stackoverflow.com/a/48365609)

# Testing & development

Quick test (no integration tests):
```
mix test
```

Longer-running integration tests (requires compiling contracts):
```
mix test --only integration
```

For other kinds of checks, refer to the CI/CD pipeline (`Jenkinsfile`).

To run a development `iex` REPL with all code loaded:
```
iex -S mix run --no-start
```
