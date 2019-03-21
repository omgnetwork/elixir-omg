# 1. Installation via Vagrant
Refer to https://github.com/omisego/xomg-vagrant.

# 2. Full installation

**NOTE**: Currently the child chain server and watcher are bundled within a single umbrella app.

Only **Linux** platforms are supported now. These instructions have been tested on a fresh Linode 2048 instance with Ubuntu 16.04.

## Prerequisites
* **Erlang OTP** `>=20` (check with `elixir --version`)
* **Elixir** `>=1.6` (check with `elixir --version`)
* **solc** `>=0.4.24` (check with `solc --version`)

### Optional prerequisites
* **`httpie`** - to run HTTP requests from `docs/demoxx.md` demos

## Install prerequisite packages
```
sudo apt-get update
sudo apt-get -y install build-essential autoconf libtool libgmp3-dev libssl-dev wget git
```

## Install Erlang

Add the Erlang Solutions repo and install
```
wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb
sudo dpkg -i erlang-solutions_1.0_all.deb
sudo apt-get update
sudo apt-get install -y esl-erlang
```

## Install Elixir
```
sudo apt-get -y install elixir
```


## Install Geth
```
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt-get update
sudo apt-get -y install geth
```

### Installing Parity
[Parity]((https://www.parity.io/ethereum/)) is supported. To use it, download the binary and put it into your PATH.

## Install solc
```
sudo apt-get install libssl-dev solc
```

## Install hex and rebar
```
mix do local.hex --force, local.rebar --force
```

## Clone repo
```
git clone https://github.com/omisego/elixir-omg
```

## Build
```
cd elixir-omg
mix deps.get
```

## Check this works!
For a quick test (with no integration tests)
```
mix test
```

To run integration tests (requires compiling contracts and **not** having `geth` running in the background):
```
mix test --only integration
```

To run test with parity as a backend, set it via `export ETH_NODE=parity` environmental variable or via config. E.g. 
```
ETH_NODE=parity mix test --only integration
```
