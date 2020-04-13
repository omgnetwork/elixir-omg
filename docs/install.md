# Full Installation

**NOTE**: Currently the child chain server and watcher are bundled within a single umbrella app.

Only **Linux** and **OSX** platforms are supported now. These instructions have been tested on a fresh Linode 2048 instance with Ubuntu 16.04.

## Prerequisites
* **Erlang OTP** `>=22` (check with `elixir --version`)
* **Elixir** `=1.10.*` (check with `elixir --version`)

## Install prerequisite packages
It will install common development tools, geth and postgres.

```
sh bin/setup
```

## Install Erlang and Elixir

Add the Erlang Solutions repo and install
```
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb \
&& sudo apt install ./erlang-solutions_2.0_all.deb \
&& rm ./erlang-solutions_2.0_all.deb
sudo apt-get update
sudo apt-get install esl-erlang=1:22.3.1-1 elixir=1.10.2-1
sudo apt-get install -y erlang-os-mon erlang-parsetools erlang-tools
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
