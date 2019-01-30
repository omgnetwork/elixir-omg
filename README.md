<img src="docs/assets/logo.png" align="right" />

The `elixir-omg` repository contains OmiseGO's Elixir implementation of Plasma and forms the basis for the OMG Network.

[![Build Status](https://circleci.com/gh/omisego/elixir-omg.svg?style=svg)](https://circleci.com/gh/omisego/elixir-omg) [![Coverage Status](https://coveralls.io/repos/github/omisego/elixir-omg/badge.svg?branch=master)](https://coveralls.io/github/omisego/elixir-omg?branch=master) [![Gitter chat](https://badges.gitter.im/omisego/elixir-omg.png)](https://gitter.im/omisego/elixir-omg)

**IMPORTANT NOTICE: Heavily WIP, expect anything**

**Table of Contents**

<!--ts-->
   * [Getting Started](#getting-started)
      * [Install](#install)
      * [Setup](#setup)
         * [Setting up a child chain server (a developer environment)](#setting-up-a-child-chain-server-a-developer-environment)
            * [Start up developer instance of Ethereum](#start-up-developer-instance-of-ethereum)
               * [Persistent developer geth instance](#persistent-developer-geth-instance)
            * [Prepare and configure the root chain contract](#prepare-and-configure-the-root-chain-contract)
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
            * [Http-RPC](#http-rpc)
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

<!-- Added by: user, at: 2018-10-22T11:44+02:00 -->

<!--te-->

<!-- Created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc) -->
<!-- .gh-md-toc --insert README.md -->

The first release of the OMG Network is based upon **Tesuji Plasma**, an iterative design step over [Plasma MVP](https://github.com/omisego/plasma-mvp). The diagram below illustrates the relationship between the wallet provider and how wallet providers connect to **Tesuji Plasma**.

![eWallet server and OMG Network](docs/assets/OMG-network-eWallet.jpg)

See the [Tesuji Plasma design document](docs/tesuji_blockchain_design.md) for a full description for the Child Chain Server and Watcher.
**NOTE** not all parts of that design have been implemented!

# Getting Started

A public testnet for the OMG Network is coming soon. However, if you are brave and want to test being a Tesuji Plasma chain operator, read on!

## Service start up using Docker Compose
This is the recommended method of starting the blockchain services, with the auxiliary services automatically provisioned through Docker. Before attempting the start up please ensure that you are not running any services that are listing on the following TCP ports: 9656, 7434, 5000, 8545, 5432, 5433. All commands should be run from the root of the repo.

### Mac
`docker-compose up`

### Linux
`docker-compose -f docker-compose.yml -f docker-compose-non-mac.yml up`

### Troubleshooting
You can view the running containers via `docker ps`

If service start up is unsuccessful, containers can be left hanging which impacts the start of services on the future attempts of `docker-compose up`. You can stop all running containers via `docker kill $(docker ps -q)`.

If the blockchain services are not already present on the host, docker-compose will attempt to build the image with the tag `elixir-omg:dockercompose` and continue to use that. If you want Docker to use the latest commit from `elixir-omg` you can trigger a fresh build by passing the `--build` flag to `docker-compose up --build`.

## Install on a Linux host & manual start up
Follow the guide to **[install](docs/install.md)** the child chain server and watcher. Then use the guide in **[manual service startup](docs/manual_service_startup.md)** to stand up.

### Follow the demos
After starting the child chain server and/or Watcher as above, you may follow the steps in the demo scripts.
Note that some steps should be performed in the Elixir shell (iex) and some in the shell directly.

To start a configured instance of the `iex` REPL, from the `elixir-omg` root directory do:
```bash
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
  - `omg_rpc` - a Http-RPC server being the gateway to `omg_api`
  - `omg_performance` - performance tester for the child chain server
  - `omg_watcher` - Phoenix app that runs the Watcher

See [application architecture](docs/architecture.md) for more details.

## Child chain server

`:omg_api` is the Elixir app which runs the child chain server, whose API is exposed by `:omg_rpc`.

For the responsibilities and design of the child chain server see [Tesuji Plasma Blockchain Design document](docs/tesuji_blockchain_design.md).

### Using the child chain server's API

#### Http-RPC

Http-RPC requests are served up on the port specified in `omg_rpc`'s `config` (`9656` by default).
The available RPC calls are defined by `omg_api` in `api.ex` - paths follow RPC convention e.g. `block.get`, `transaction.submit`. All requests shall be POST with parameters provided in the request
body in JSON object. Object's properties names correspond to the names of parameters. Binary values
shall be hex-encoded strings.

##### `transaction.submit`

Request:

`POST /transaction.submit`
body:
```json
{
  "transaction":"rlp encoded plasma transaction in hex"
}
```

See the [step by step transaction generation specs here](docs/tesuji_tx_integration.md).

Response:

```json
{
    "version": "1",
    "success": true,
    "data": {
        "blknum": 123000,
        "txindex": 111,
        "txhash": "transaction hash in hex"
    }
}
```

##### `block.get`

Request:

`POST /block.get`
body:
```json
{
  "hash":"block hash in hex"
}
```

Response:

```json
{
  "version": "1",
  "success": true,
  "data": {
      "blknum": 123000,
      "hash": "block hash in hex",
      "transactions": [
          "rlp encoded plasma transaction in hex",
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
In case extra finality is required for high-stakes transactions, the client is free to wait any number of Ethereum blocks (confirmations) on top of `submitted_at_ethheight`.

```json
{
  "topic": "transfer:0xfd5374cd3fe7ba8626b173a1ca1db68696ff3692",
  "ref": null,
  "payload": {
    "child_blknum": 10000,
    "child_txindex": 12,
    "child_block_hash": "0x0017372421f9a92bedb7163310918e623557ab5310befc14e67212b660c33bec",
    "submited_at_ethheight": 14,
    "tx": {
      "signed_tx": {
        "raw_tx": {
          "amount1": 7,
          "amount2": 3,
          "blknum1": 2001,
          "blknum2": 0,
          "cur12": "0x0000000000000000000000000000000000000000",
          "newowner1": "0xb3256026863eb6ae5b06fa396ab09069784ea8ea",
          "newowner2": "0xae8ae48796090ba693af60b5ea6be3686206523b",
          "oindex1": 0,
          "oindex2": 0,
          "txindex1": 0,
          "txindex2": 0
        },
        "sig1": "0x6bfb9b2dbe32 ...",
        "sig2": "0xcedb8b31d1e4 ...",
        "signed_tx_bytes": "0xf3170101c0940000..."
      },
      "tx_hash": "0xbdf562c24ace032176e27621073df58ce1c6f65de3b5932343b70ba03c72132d",
      "spender1": "0xbfdf85743ef16cfb1f8d4dd1dfc74c51dc496434",
      "spender2": "0xb3256026863eb6ae5b06fa396ab09069784ea8ea"
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

These should be treated as a prompt to mass exit immediately.

Events:

**invalid_block**

Event informing about that particular block is invalid

**unchallenged_exit**

Event informing about a particular, invalid, active exit having gone too long without being challenged, jeopardizing funds in the child chain.

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

To install dependencies:
```bash
sudo apt-get install libssl-dev solc
```

Contracts will compile automatically as a regular mix dependency.
To compile contracts manually:
```bash
mix deps.compile plasma_contracts
```

# Testing & development

Quick test (no integration tests):
```bash
mix test
```

Longer-running integration tests (requires compiling contracts):
```bash
mix test --only integration
```

For other kinds of checks, refer to the CI/CD pipeline (https://circleci.com/gh/omisego/workflows/elixir-omg).

To run a development `iex` REPL with all code loaded:
```bash
iex -S mix run --no-start
```

# Working with API Spec's

This repo contains `gh-pages` branch intended to host [Slate-based](https://omisego.github.io/elixir-omg) API specification. Branch `gh-pages` is totally diseparated from other development branches and contains just Slate generated page's files.

See [gh-pages README](https://github.com/omisego/elixir-omg/blob/gh-pages/docs/api_specs/README.md) for more details.
