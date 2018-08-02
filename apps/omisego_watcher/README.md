# OmiseGO Watcher

**IMPORTANT NOTICE: Heavily WIP, expect anything**

The Watcher is an observing node that connects to Ethereum and the child chain server's API.
It exposes the information it gathers via a REST interface (Phoenix)
For the responsibilities and design of the watcher see [Tesuji Plasma Blockchain Design document](FIXME link pending).

**TODO** write proper README after we distill how to run this.

## Configure the `omisego_watcher` app
Create another copy of the configuration file. The values for `contract_addr`, `txhash_contract` and `authority_addr` should be the same as the `omisego_api` app. However, `leveldb_path` should be set to a different directory than `omisego_watcher`.

The confiration file should look something like this:

```
use Mix.Config
config :omisego_eth,
  contract_addr: "0x005f49af1af9eee6da214e768683e1cc8ab222ac",
  txhash_contract: "0x3afd2c1b48eaa3100823de1924d42bd48ee25db1fd497998158f903b6a841e92",
  authority_addr: "0x5c1a5e5d94067c51ec51c6c00416da56aac6b9a3"
  leveldb_path: Path.join([System.get_env("HOME"), "~/omisego/data_watcher"])

```

## Setting up and running the watcher

```
cd apps/omisego_watcher
# FIXME: wouldn't work yet but would belong here: mix run --no-start -e 'OmiseGO.DB.init()'
iex --sname watcher -S mix
```

## Setting up (developer's environment)

  - setup and run the child chain server in developer's environment
  - setup and run the watcher pointing to the same `omisego_eth` configuration (with the contract address) as the child chain server

## Using the watcher

FIXME adapt to how it actually works

### Endpoints

`/utxos/<address>`
`/transactions/<tx_hash>`
