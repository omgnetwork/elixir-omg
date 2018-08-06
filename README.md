# OmiseGO

For the child chain server, see [apps/omisego_api](apps/omisego_api).

For the watcher, see [apps/omisego_watcher](apps/omisego_watcher).

For generic information, keep on reading.

**IMPORTANT NOTICE: Heavily WIP, expect anything**

## Installation

**NOTE**: Currently the child chain server and watcher are bundled within a single umbrella app.

### Prerequisites

Only **Linux** platforms supported now. Known to work with Ubuntu 16.04

  - Install [Elixir](http://elixir-lang.github.io/install.html#unix-and-unix-like).
    **OTP 20 is required**, meaning that on Ubuntu, you should modify steps in the linked instructions:
    `sudo apt install esl-erlang=1:20.3.6`

    **TODO**: revert the requirement when we migrate to OTP 21 in OMG-181
  - Install an Ethereum node (e.g. [geth](https://github.com/ethereum/go-ethereum/wiki/geth))
  - If required, install the following packages:
    `sudo apt-get install build-essential autoconf libtool libgmp3-dev`
  - **Watcher only** install PostgreSQL

### OmiseGO child chain server and watcher

**TODO** hex-ify the package.

  - `git clone https://github.com/omisego/omisego` - clone this repo
  - `cd omisego`
  - `mix deps.get`
  - If you want to compile/test/deploy contracts see `populus/README.md` for instructions

## Testing & development

  - quick test (no integration tests): `mix test`
  - longer-running integration tests: `mix test --only integration` (requires compiling contracts)

For other kinds of checks, refer to the CI/CD pipeline (`Jenkinsfile`).

  - to run a development `iex` REPL with all code loaded: `iex -S mix run --no-start`

## Setting up

The setup process for the Child chain server and for the Watcher is quite similar:

1. Provide an Ethereum node running connected to the appropriate network
1. Initialize the child chain server's `OmiseGO.DB` database.
Do that with `mix run --no-start -e 'OmiseGO.DB.init()'`
1. (**Child chain server only**) Deploy `RootChain.sol` contract and prepare operator's authority address
1. Produce a configuration file with `omisego_eth` configured to the contract address, operator (authority) address and hash of contract-deploying transaction.
To do that use the template, filling it with details on the contract:

        use Mix.Config

        config :omisego_eth,
          contract_addr: "0x0",
          authority_addr: "0x0",
          txhash_contract: "0x0"
