# 1. Installation via Vagrant
Refer to https://github.com/omisego/omisego-vagrant.

# 2. Full installation

**NOTE**: Currently the child chain server and watcher are bundled within a single umbrella app.

**TODO** hex-ify the package.

Only **Linux** platforms are supported now. These instructions have been tested on a fresh Linode 2048 instance with Ubuntu 16.04.

## Prerequisites
* Elixir
* Erlang OTP 20
* Python '>=3.5, <4'
* solc 0.4.24

## Install prerequisite packages
```
sudo apt-get update
sudo apt-get -y install build-essential autoconf libtool libgmp3-dev libssl-dev wget git
```

## Install Erlang OTP 20
**TODO**: This step is only required until we migrate to OTP 21 in OMG-181

Add the Erlang Solutions repo
```
wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && sudo dpkg -i erlang-solutions_1.0_all.deb
sudo apt-get update
sudo apt-get install -y esl-erlang=1:20.3.6
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

## Install rebar
```
mix do local.hex --force, local.rebar --force
```

## Clone repo
```
git clone https://github.com/omisego/omisego
```

## Install populus
[Ref](../populus/README.md)
```
pip3 install -r omisego/populus/requirements.txt
```
If an error is raised when installing the specific version of `eth-utils`, the error may be ignored for the purposes of this installation.

## Build
```
# populus requires character encoding to be set
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

cd omisego
mix deps.get
```

## Check this works!
For a quick test (with no integration tests)
```
mix test
```

To run integration tests (requires compiling contracts)
```
mix test --only integration
```

## Next steps
Follow the README steps for the [child chain server](../apps/omisego_api/README.md).
