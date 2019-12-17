# Full Installation

**NOTE**: Currently the child chain server and watcher are bundled within a single umbrella app.

Only **Linux** platforms are supported now. These instructions have been tested on a fresh Linode 2048 instance with Ubuntu 16.04.

## Prerequisites
* **Erlang OTP** `>=20` (check with `elixir --version`)
* **Elixir** `>=1.6` (check with `elixir --version`)
* **solc** `~>0.5` (check with `solc --version`)

### Optional prerequisites
* **`httpie`** - to run HTTP requests from `docs/demoxx.md` demos

## Install prerequisite packages

```
sudo apt-get update
sudo apt-get -y install \
  autoconf \
  build-essential \
  cmake \
  git \
  libgmp3-dev \
  libsecp256k1-dev \
  libssl-dev \
  libtool \
  wget
```

## Install PostgreSQL

```
sudo apt-get install postgresql postgresql-contrib
sudo -u postgres createuser omisego_dev
sudo -u postgres psql -c "alter user omisego_dev with encrypted password 'omisego_dev'"
sudo -u postgres psql -c "alter user omisego_dev CREATEDB"
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

## Installing Parity
Parity is supported. To use it, download the [lastest stable
binary](https://www.parity.io/ethereum/#download) and put it into your PATH.

```
wget https://releases.parity.io/ethereum/v2.4.6/x86_64-unknown-linux-gnu/parity
chmod +x parity
sudo mv parity /usr/bin/
```

## Install solc
```
sudo apt-get install libssl-dev solc
wget https://github.com/ethereum/solidity/releases/download/v0.4.26/solidity-ubuntu-trusty.zip
unzip solidity-ubuntu-trusty.zip
sudo install solc /usr/local/bin
rm solc lllc solidity-ubuntu-trusty.zip
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
mix deps.compile
```

## Check this works!
For a quick test (with no integration tests)
```
mix test
```

To run integration tests (requires compiling contracts and **not** having `geth` running in the background):
```
mix test --trace --only integration
```
