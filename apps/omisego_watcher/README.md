# OmiseGO Watcher

**IMPORTANT NOTICE: Heavily WIP, expect anything**

The Watcher is an observing node that connects to Ethereum and the child chain server's API.
It exposes the information it gathers via a REST interface (Phoenix)
For the responsibilities and design of the watcher see [Tesuji Plasma Blockchain Design document](FIXME link pending).

**TODO** write proper README after we distill how to run this.

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
