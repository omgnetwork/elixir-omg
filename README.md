<img src="assets/logo.png" align="right" />

# elixir-omg
The `elixir-omg` repository contains OmiseGO's Elixir implementation of Plasma and forms the basis for the OMG Network.

**IMPORTANT NOTICE: Heavily WIP, expect anything**

The first release of the OMG Network is based upon **Tesuji Plasma**, an iterative design step over [Plasma MVP](../plasma-mvp). The diagram below illustrates the relationship between the wallet provider and how wallet providers connect to **Tesuji Plasma**.

![eWallet server and OMG Network](assets/OMG-network-eWallet.jpg)

See the [Tesuji Plasma design document](docs/tesuji_blockchain_design.md) for a full description for the Child Chain Server and Watcher.

A description of the [application architecture](docs/architecture.md) may be found in the `docs` directory.

For specific documentation about the child chain server, see [`apps/omg_api/`](apps/omg_api).

For specifics on the watcher, see [`apps/omg_watcher/`](apps/omg_watcher).

For information about the smart contracts used, see [`contracts/`](contracts).

For generic information, keep on reading.

## Getting Started

A public testnet for the OMG Network is not yet available. However, if you are brave and want to test being a Tesuji Plasma chain operator, read on!

### Install
Firstly, **[install](docs/install.md)** the child chain server and watcher.

### Setting up
The setup process for the Child chain server and for the Watcher is quite similar:

1. Run an Ethereum node connected to the appropriate network and make sure it's ready to use
  - currently only connections via RPC over HTTP are supported, defaulting to `http://localhost:8545`.
  To customize that, append `config :ethereumex, url: "http://localhost:8545"` to configuration files you use
  - `Byzantium` is required to be in effect on the Ethereum network you connect to
1. Initialize the child chain server's `OMG.DB` database.
Do that with `mix run --no-start -e 'OMG.DB.init()'`
1. (**Child chain server only**) Prepare the authority address and deploy `RootChain.sol`.
**Authority address** belongs to the child chain operator, and is used to run the child chain (submit blocks to the root chain contract)
1. Produce a configuration file with `omg_eth` configured to the contract address, authority address and hash of contract-deploying transaction.
To do that use the template, filling it with details on the contract:

        use Mix.Config

        config :omg_eth,
          contract_addr: "0x0",
          authority_addr: "0x0",
          txhash_contract: "0x0"

Such configuration must become part of the [Mix configuration](https://hexdocs.pm/mix/Mix.Config.html) for the app you're going to be running.
That is either the file you're providing with the `--config` flag or file living under your `<mix_app>/config/config.exs`.

See [Child chain server](apps/omg_api) and [Watcher](apps/omg_watcher) specific `README`s for detailed instructions on setting up developer environments.

### Troubleshooting
Solutions to common problems may be found in the [troubleshooting](docs/troubleshooting.md) document.

### Testing & development

- Quick test (no integration tests):
```
mix test
```
- Longer-running integration tests: ```mix test --only integration``` (requires compiling contracts)

For other kinds of checks, refer to the CI/CD pipeline (`Jenkinsfile`).

- To run a development `iex` REPL with all code loaded:
```
iex -S mix run --no-start
```
