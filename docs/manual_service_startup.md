# Manual steps to start the services
This process is intended for users who wish to start services manually, perhaps as part of a non-Docker deployment on a Linux host.

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
1. (**Watcher only**) Configure the child chain url (default is `http://localhost:9656`) by configuring `:omg_rpc, OMG.RPC.Web.Endpoint` with `http: [port: 9656]`
1. (**Watcher only**) Initialize the Watcher's `OMG.DB` database
1. (**Watcher only**) Create and migrate the PostgreSQL `WatcherDB` database
1. (**Watcher only**) At this point the Watcher should be properly setup to run by starting the `omg_watcher` Mix app

### Setting up a child chain server (a developer environment)
#### Start up developer instance of Ethereum
The easiest way to get started is if you have access to a developer instance of `geth`.
If you don't already have access to a developer instance of `geth`, follow the [installation](docs/install.md) instructions.

A developer instance of `geth` runs Ethereum locally and prefunds an account.
However, when `geth` terminates, the state of the Ethereum network is lost.

```bash
geth --targetgaslimit "6200000" --dev --dev.period 1 --rpc --rpcapi personal,web3,eth,net  --rpcaddr 0.0.0.0
```

##### Persistent developer `geth` instance
Alternatively, a persistent developer instance that does not lose state can be started with the following command:
```bash
geth --targetgaslimit "6200000" --dev --dev.period 1 --rpc --rpcapi personal,web3,eth,net  --rpcaddr 0.0.0.0 --datadir ~/.geth
```

#### Connecting to a non-dev chain

Another alternative might be running the whole setup on some official testnet, ex. `rinkeby`.

```bash
geth --rinkeby --rpc --rpcapi personal,web3,eth,net  --rpcaddr 127.0.0.1
```

**NOTE** Contrary to working with developer instance, operator's account must be manually funded with testnet Ether.

#### Using Parity

Parity can be used instead of Geth. Two environment variables must be set:
* `ETH_NODE=parity` - to tell watcher and or child-chain to use parity.
* `SIGNER_PASSPHRASE=your-passphrase` - for the child chain server, to [unlock](https://github.com/paritytech/parity-ethereum/issues/1215#issuecomment-224317361) the account.

#### Prepare and configure the root chain contract

The following step will:
- create, fund and unlock the authority address
- deploy the root chain contract
- create the config file

Note that `geth` needs to already be running for this step to work!

From the root dir of `elixir-omg`:
```bash
mix compile
mix run --no-start -e \
 '
   contents = OMG.Eth.DevHelpers.prepare_env!() |> OMG.Eth.DevHelpers.create_conf_file()
   "~/config.exs" |> Path.expand() |> File.write!(contents)
 '
```

The result should look something like this (use `cat ~/config.exs` to check):
```elixir
use Mix.Config
config :omg_eth,
  contract_addr: "0x005f49af1af9eee6da214e768683e1cc8ab222ac",
  txhash_contract: "0x3afd2c1b48eaa3100823de1924d42bd48ee25db1fd497998158f903b6a841e92",
  authority_addr: "0x5c1a5e5d94067c51ec51c6c00416da56aac6b9a3"
```
The above values are only demonstrative, **do not** copy and paste!

Note that you'll need to pass the configuration file each time you run `mix` with the following parameter `--config ~/config.exs` flag

**NOTE** If you're using persistent `geth` and `geth` is restarted after the above step, the authority account must be unlocked again:

```bash
geth attach http://127.0.0.1:8545
personal.unlockAccount(“<authority_addr from ~/config.exs>”, 'ThisIsATestnetPassphrase', 0)
```
The passphrase mentioned above originates from [`dev_helpers`](apps/omg_eth/test/support/dev_helpers.ex).
It is what is used when deploying the contract in the `dev` environment using `prepare_env!()` as above.

##### Deployment on non-dev chain

The above configuration assumes that the contract is deployed on a dev instance of  `geth` which has unlimited `Eth` supply.
To deploy `child chain` on in an environment with limited `Eth` provide `:faucet` and `:initial_funds` options to `prepare_env!` function.

**NOTE**: the faucet account must first be unlocked and funded
**NOTE**: the newly created `authority` address needs refunding from time to time (preferably done by `geth attach`)

#### Initialize the child chain database
Initialize the database with the following command.
**CAUTION** This wipes the old data clean!:
```bash
rm -rf ~/.omg/data
mix run --no-start -e 'OMG.DB.init()'
```

The database files are put at the default location `~/.omg/data`.
You need to re-initialize the database, in case you want to start a new child chain from scratch!

#### Start it up!
* Start up geth if not already started.
* Start Up the child chain server:

```bash
iex -S mix xomg.child_chain.start --config ~/config.exs
```

### Setting up a Watcher (a developer environment)

This assumes that you've got a developer environment Child chain server set up and running on the default `localhost:9656`, see above.

#### Configure the PostgreSQL server with:

```bash
sudo -u postgres createuser omisego_dev
sudo -u postgres psql
alter user omisego_dev with encrypted password 'omisego_dev';
ALTER USER omisego_dev CREATEDB;
```

#### Configure the Watcher

Copy the configuration file used by the Child chain server to `~/config_watcher.exs`

```bash
cp ~/config.exs ~/config_watcher.exs
```

You need to use a **different** location of the `OMG.DB` for the Watcher, so in `~/config_watcher.exs` append the following:

```elixir
config :omg_db,
  leveldb_path: Path.join([System.get_env("HOME"), ".omg/data_watcher"])
```

#### Initialize the Watcher's databases

**CAUTION** This wipes the old data clean!

```bash
rm -rf ~/.omg/data_watcher
mix ecto.reset --no-start
mix run --no-start -e 'OMG.DB.init()' --config ~/config_watcher.exs
```

#### Start the Watcher

It is possible to run the watcher in two different modes: "`security critical`" and "`security critical` + `convenience`"
The one that should be chosen currently is `security critical` + `convenience` mode, which provides all the expected functionality:

```bash
iex -S mix xomg.watcher.start --convenience --config ~/config_watcher.exs
```

> "security critical" mode can be started by omitting the `--convenience` flag, but this not fully implemented yet

See docs/TODO for more details about watcher modes.
