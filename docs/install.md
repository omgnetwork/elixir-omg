# 1. Installation via Vagrant
Refer to https://github.com/omisego/xomg-vagrant.

# 2. Full installation

**NOTE**: Currently the child chain server and watcher are bundled within a single umbrella app.

Only **Linux** platforms are supported now. These instructions have been tested on a fresh Linode 2048 instance with Ubuntu 16.04.

## Prerequisites
* **Erlang OTP** `>=20` (check with `elixir --version`)
* **Elixir** `>=1.6` (check with `elixir --version`)
* **Python** `>=3.5, <4` (check with `python --version`)
* **solc** `>=0.4.24` (check with `solc --version`)

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

## Install pip3
```
sudo apt-get -y install python3-pip
```

## (optional) Install virtualenv
This step is optional but recommended to isolate the python environment. [Ref](https://gist.github.com/IamAdiSri/a379c36b70044725a85a1216e7ee9a46)
```
sudo pip3 install virtualenv
virtualenv DEV
source DEV/bin/activate
```

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

## Install contract building machinery
[Ref](../README.md#contracts)
```
# contract building requires character encoding to be set
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
pip3 install -r contracts/requirements.txt
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
