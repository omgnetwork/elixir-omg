# OmiseGO
The OmiseGO repository contains OmiseGO's implementation of Plasma and forms the base layer for the OMG Network.

The first release of the OMG Network is based upon **Tesuji Plasma**, an interation over PlasmaMVP.

The diagram below illustrates the relationship between the wallet provider and how wallet providers connect to **Tesuji Plasma**.

![eWallet server and OMG Network](assets/OMG-network-eWallet.jpg)

For the child chain server, see [apps/omisego_api](apps/omisego_api).

For the watcher, see [apps/omisego_watcher](apps/omisego_watcher).

For generic information, keep on reading.

## Getting Started
**IMPORTANT NOTICE: Heavily WIP, expect anything**

A public testnet for the OMG Network is not yet available. However, if you are brave and want to become a Tesuji Plasma chain operator, read on!

### Install
Firstly, **[install](docs/install.md)** the child chain server and watcher.

### Start up developer instance of Ethereum
The easiest way to get started is if you have access to a developer instance of `geth`. If you don't already have access to a developer instance of `geth`, the above installation instructions will install `geth`.

A developer instance of geth runs Ethereum locally and prefunds an account. However, when the process terminates, the state of the Ethereum network is lost.

```
geth --dev --dev.period 2 --rpc --rpcapi personal,web3,eth
```

### Persistent developer instance
Alternatively, a persistent developer instance can be started by:
```
geth --dev --dev.period 2 --rpc --rpcapi personal,web3,eth  --datadir ~/.geth --ipc
```

After `geth` starts, the authority account must be unlocked

```
geth attach http://127.0.0.1:8545
personal.unlockAccount(“<authority_addr from config.exs>”, '', 0)
```

### Configure the `omisego_eth` app

The following step will deploy the root chain contract and configure your app:
Note that geth needs to already be running for this step to work!
```
mix run --no-start -e \
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

Initialize the child chain database
```
mix run --no-start -e 'OmiseGO.DB.init()'
```

### Configure the `omisego_watcher` app
Create another copy of the configuration file.

```
use Mix.Config
config :omisego_eth,
  contract_addr: "0x005f49af1af9eee6da214e768683e1cc8ab222ac",
  txhash_contract: "0x3afd2c1b48eaa3100823de1924d42bd48ee25db1fd497998158f903b6a841e92",
  authority_addr: "0x5c1a5e5d94067c51ec51c6c00416da56aac6b9a3"
  leveldb_path: Path.join([System.get_env("HOME"), ".omisego/data_watcher"])

```


### Start it all up!
* Start up geth if not already started.
* Start Up the child chain server
```
cd ~/DEV/omisego/apps/omisego_jsonrpc
mix run --no-halt --config ~/config.exs
```

### Resuming the child chain
* Resume geth using the following command:
```
geth --dev --dev.period 2 --rpc --rpcapi personal,web3,eth  --datadir ~/.geth --ipc
```

* Unlock the authority account
```
geth attach http://127.0.0.1:8545
personal.unlockAccount(“<authority_addr from config.exs>”, '', 0)
```

* Start the child chain as above

### Follow the demonstration
Note that some steps should be performed in the Elixir shell (iex) and some in the shell directly.
https://github.com/omisego/omisego/blob/develop/docs/demo_01.md

Interact with the Child Chain in Elixir!
A different way of interacting with the child chain server is via the awesome Elixir REPL.
```
cd DEV/omisego/
iex -S mix run --no-start --config ~/config.exs
```

If httpie (the http command is not available):
```
sudo apt-get -y install httpie
```

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
