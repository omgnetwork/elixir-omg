<img src="docs/assets/logo.png" align="right" />

The `elixir-omg` repository contains OmiseGO's Elixir implementation of Plasma and forms the basis for the OMG Network.

[![Build Status](https://circleci.com/gh/omisego/elixir-omg.svg?style=svg)](https://circleci.com/gh/omisego/elixir-omg) [![Coverage Status](https://coveralls.io/repos/github/omisego/elixir-omg/badge.svg?branch=master)](https://coveralls.io/github/omisego/elixir-omg?branch=master) [![Gitter chat](https://badges.gitter.im/omisego/elixir-omg.png)](https://gitter.im/omisego/elixir-omg)

**IMPORTANT NOTICE: Heavily WIP, expect anything**

**Table of Contents**

<!--ts-->
   * [Getting Started](#getting-started)
      * [Service start up using Docker Compose](#service-start-up-using-docker-compose)
         * [Mac](#mac)
         * [Linux](#linux)
         * [Get the deployed contract details](#get-the-deployed-contract-details)
         * [Troubleshooting Docker](#troubleshooting-docker)
      * [Install on a Linux host &amp; manual start up](#install-on-a-linux-host--manual-start-up)
         * [Follow the demos](#follow-the-demos)
      * [Troubleshooting](#troubleshooting)
   * [elixir-omg applications](#elixir-omg-applications)
      * [Child chain server](#child-chain-server)
         * [Using the child chain server's API](#using-the-child-chain-servers-api)
            * [HTTP-RPC](#http-rpc)
         * [Running a child chain in practice](#running-a-child-chain-in-practice)
            * [Private key management](#private-key-management)
            * [Specifying the fees required](#specifying-the-fees-required)
            * [Funding the operator address](#funding-the-operator-address)
      * [Watcher](#watcher)
         * [Using the watcher](#using-the-watcher)
         * [Endpoints](#endpoints)
         * [Private key management](#private-key-management-1)
      * [Contracts](#contracts)
         * [Installing dependencies and compiling contracts](#installing-dependencies-and-compiling-contracts)
   * [Testing &amp; development](#testing--development)
   * [Working with API Spec's](#working-with-api-specs)

<!-- Added by: user, at: 2019-03-29T14:02+01:00 -->

<!--te-->

<!-- Created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc) -->
<!-- GH_TOC_TOKEN=75... ./gh-md-toc --insert ../omisego/README.md -->

The first release of the OMG Network is based upon **Tesuji Plasma**, an iterative design step over [Plasma MVP](https://github.com/omisego/plasma-mvp).
The diagram below illustrates the relationship between the wallet provider and how wallet providers connect to **Tesuji Plasma**.

![eWallet server and OMG Network](docs/assets/OMG-network-eWallet.jpg)

See the [Tesuji Plasma design document](docs/tesuji_blockchain_design.md) for a full description for the Child Chain Server and Watcher.
**NOTE** not all parts of that design have been implemented!

# Getting Started

A public testnet for the OMG Network is coming soon.
However, if you are brave and want to test being a Tesuji Plasma chain operator, read on!

## Service start up using Docker Compose
This is the recommended method of starting the blockchain services, with the auxiliary services automatically provisioned through Docker.
Before attempting the start up please ensure that you are not running any services that are listening on the following TCP ports: 9656, 7434, 5000, 8545, 5432, 5433.
All commands should be run from the root of the repo.

### Mac
`docker-compose up`

### Linux
`docker-compose -f docker-compose.yml -f docker-compose-non-mac.yml up`

### Get the deployed contract details

`curl localhost:5000/get_contract`

### Troubleshooting Docker
You can view the running containers via `docker ps`

If service start up is unsuccessful, containers can be left hanging which impacts the start of services on the future attempts of `docker-compose up`.
You can stop all running containers via `docker kill $(docker ps -q)`.

If the blockchain services are not already present on the host, docker-compose will attempt to build the image with the tag `elixir-omg:dockercompose` and continue to use that.
If you want Docker to use the latest commit from `elixir-omg` you can trigger a fresh build by passing the `--build` flag to `docker-compose up --build`.

## Install on a Linux host & manual start up
Follow the guide to **[install](docs/install.md)** the child chain server and watcher.
Then use the guide in **[manual service startup](docs/manual_service_startup.md)** to stand up.

### Follow the demos
After starting the child chain server and/or Watcher as above, you may follow the steps in the demo scripts.
Note that some steps should be performed in the Elixir shell (iex) and some in the shell directly.

To start a configured instance of the `iex` REPL, from the `elixir-omg` root directory inside the container do:
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
    - see `apps/omg_api/lib/application.ex` for a rundown of children processes involved
  - `omg_db` - wrapper around the child chain server's database to store the UTXO set and blocks necessary for state persistence
  - `omg_eth` - wrapper around the [Ethereum RPC client](https://github.com/exthereum/ethereumex)
  - `omg_rpc` - an HTTP-RPC server being the gateway to `omg_api`
  - `omg_performance` - performance tester for the child chain server
  - `omg_watcher` - the [Watcher](#watcher)

See [application architecture](docs/architecture.md) for more details.

## Child chain server

`:omg_api` is the Elixir app which runs the child chain server, whose API is exposed by `:omg_rpc`.

For the responsibilities and design of the child chain server see [Tesuji Plasma Blockchain Design document](docs/tesuji_blockchain_design.md).

### Using the child chain server's API

The child chain server is listening on port `9656` by default.

#### HTTP-RPC

HTTP-RPC requests are served up on the port specified in `omg_rpc`'s `config` (`:omg_rpc, OMG.RPC.Web.Endpoint, http: [port: ...]`).
The available RPC calls are defined by `omg_api` in `api.ex` - paths follow RPC convention e.g. `block.get`, `transaction.submit`.
All requests shall be POST with parameters provided in the request body in JSON object.
Object's properties names correspond to the names of parameters. Binary values shall be hex-encoded strings.

For API documentation see: https://omisego.github.io/elixir-omg.

### Running a child chain in practice

**TODO** other sections

#### Private key management

Currently, the child chain server assumes that the authority account is unlocked or otherwise available on the Ethereum node.
This might change in the future.

**NOTE** on `parity` - the above comment is relevant for `geth`.
Since `parity` doesn't support indefinite unlocking of the account, handling of such key is yet to be solved.
Currently (an unsafely) such private key is read from a secret system environment variable and handed to `parity` for signing.

#### Specifying the fees required

The child chain server will require the incoming transactions to satisfy the fee requirement.
The fee requirement reads that at least one token being inputted in a transaction must cover the fee as specified.
In particular note that the fee required cannot be paid in two tokens, splitting the payment.

The fees are configured in the config entries `:omg_api, :fee_specs_file_path` and `:omg_api, :ignore_fees`.
 - `ignore_fees` is boolean option allowing to turn off fee charging altogether.
 - `fee_specs_file_path` is path to file which define fee. Please see [fee_specs.json](fee_specs.json) for an example.

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
- 71505 gas per submission (checked for `RootChain.sol` [at this revision](https://github.com/omisego/plasma-contracts/commit/50653d52169a01a7d7d0b9e2e4e3c4a4b904f128).
C.f. [here](https://rinkeby.etherscan.io/tx/0x1a79fdfa310f91625d93e25139e15299b4ab272ae504c56b5798a018f6f4dc7b))

we get
```
gas_reserve ~= 4 * 60 * 24 / 1 * 7 * 71505 * 40 / 10**9  ~= 115 ETH
```

**NOTE** that the above calculation doesn't imply this is what is going to be used within a week, just a pessimistic scenario to calculate an adequate reserve.
If one assumes an _average_ gas price of 4 Gwei, the amount is immediately reduced to ~11.5 ETH weekly.

## Watcher

The Watcher is an observing node that connects to Ethereum and the child chain server's API.
It ensures that the child chain is valid and notifies otherwise.
It exposes the information it gathers via an HTTP-RPC interface (driven by Phoenix).
It provides a secure proxy to the child chain server's API and to Ethereum, ensuring that sensitive requests are only sent to a valid chain.

For more on the responsibilities and design of the Watcher see [Tesuji Plasma Blockchain Design document](docs/tesuji_blockchain_design.md).

### Using the watcher

The watcher is listening on port `7434` by default.

### Endpoints

For API documentation see: https://omisego.github.io/elixir-omg

### Private key management

Watcher doesn't hold or manage user's keys.
All signatures are assumed to be done outside.
A planned exception may be to allow Watcher to sign challenges, but using a non-sensitive/low-funded Ethereum account.

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

To run these tests with `parity` as a backend, set it via `ETH_NODE` environmental variable (default is `geth`):
```
ETH_NODE=parity mix test --only integration
```

For other kinds of checks, refer to the CI/CD pipeline (https://circleci.com/gh/omisego/workflows/elixir-omg).

To run a development `iex` REPL with all code loaded:
```bash
iex -S mix run --no-start
```

# Working with API Spec's

This repo contains `gh-pages` branch intended to host [Swagger-based](https://omisego.github.io/elixir-omg) API specification.
Branch `gh-pages` is totally diseparated from other development branches and contains just Slate generated page's files.

See [gh-pages README](https://github.com/omisego/elixir-omg/blob/gh-pages/docs/api_specs/README.md) for more details.
