# Full Installation

**NOTE**: Currently the child chain server and watcher are bundled within a single umbrella app.

Only **Linux** and **OSX** platforms are supported now. These instructions have been tested on a fresh Linode 2048 instance with Ubuntu 16.04.

## Prerequisites
* **Erlang OTP** `>=21` (check with `elixir --version`)
* **Elixir** `=1.8.*` (check with `elixir --version`)

## Install prerequisite packages

```
sh bin/install
```

## Install PostgreSQL

```
sudo apt-get install postgresql postgresql-contrib
sudo -u postgres createuser omisego_dev
sudo -u postgres psql -c "alter user omisego_dev with encrypted password 'omisego_dev'"
sudo -u postgres psql -c "alter user omisego_dev CREATEDB"
```

## Install Erlang and Elixir

Add the Erlang Solutions repo and install
```
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo apt-get install esl-erlang=1:21.3.8.10-1 elixir=1.8.2-1
sudo apt-get install -y erlang-os-mon
```

## Install Geth
Install Geth version 1.8.27 from the URL below. 
```
https://geth.ethereum.org/downloads/
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
make init_test
mix test
```

To run integration tests (requires **not** having `geth` running in the background):
```
make init_test
mix test --trace --only integration
```
