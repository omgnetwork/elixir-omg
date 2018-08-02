# OmiseGO
The OmiseGO repository contains OmiseGO's implementation of Plasma and forms the basis for the OMG Network.

The first release of the OMG Network is based upon **Tesuji Plasma**, an iterative design step over [Plasma MVP](../plasma-mvp). The diagram below illustrates the relationship between the wallet provider and how wallet providers connect to **Tesuji Plasma**.

![eWallet server and OMG Network](assets/OMG-network-eWallet.jpg)

See the [Tesuji Plasma design document](FIXME) for a full description for the Child Chain Server and Watcher.

A description of the [application architecture](docs/architecture.md) may be found in the `docs` directory.

For specific documentation about the child chain server, see [apps/omisego_api](apps/omisego_api).

For specifics on the watcher, see [apps/omisego_watcher](apps/omisego_watcher).

For generic information, keep on reading.

## Getting Started
**IMPORTANT NOTICE: Heavily WIP, expect anything**

A public testnet for the OMG Network is not yet available. However, if you are brave and want to test being a Tesuji Plasma chain operator, read on!

### Install
Firstly, **[install](docs/install.md)** the child chain server and watcher.

### Troubleshooting
Solutions to common problems may be found in the [troubleshooting](docs/troubleshooting.md) document.

### Testing & development

- Quick test (no integration tests):
```
mix test --no-start```
- Longer-running integration tests: ```mix test --no-start --only integration``` (requires compiling contracts)

For other kinds of checks, refer to the CI/CD pipeline (`Jenkinsfile`).

- To run a development `iex` REPL with all code loaded:
```
iex -S mix run --no-start
```
