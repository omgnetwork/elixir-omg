# 1. Installation via Vagrant
Ensure that Vagrant installed on your local machine

Create a directory and the following Vagrantfile:
```
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.provision "shell", path: "bootstrap.sh"
  config.vm.provider "virtualbox" do |v|https://appear.in/horde-omisego
        v.memory = 4096
        v.cpus = 2
    end
end
```

In the same directory Create a bash file name: bootstrap.sh with the contents of
https://gist.github.com/Pongch/b38bf178ee9f14dd31cd05fb34e96dce

Run:
```
vagrant up --provision
```

Wait a few minutes for all the dependencies to finish installing

SSH into vagrant:
```
vagrant ssh
```

Set ENVs to compile
```
source DEV/bin/activate
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
python3 -m solc.install v0.4.18
export SOLC_BINARY=/home/vagrant/.py-solc/solc-v0.4.18/bin/solc
```

Get the code and pull elixir dependencies
```
git clone https://github.com/omisego/omisego
cd omisego
HEX_HTTP_CONCURRENCY=1 HEX_HTTP_TIMEOUT=120 mix deps.get

compile and test
mix test --no-start
```

# 2. Full installation

**NOTE**: Currently the child chain server and watcher are bundled within a single umbrella app.

Only **Linux** platforms are supported now. These instructions have been tested on a fresh Linode 2048 instance with Ubuntu 16.04.

## Prerequisites
* Elixir
* Erlang OTP 20
* Python '>=3.5, <4'
* solc 0.4.24

<!-- - Install [Elixir](http://elixir-lang.github.io/install.html#unix-and-unix-like).
    **OTP 20 is required**, meaning that on Ubuntu, you should modify steps in the linked instructions:
    `sudo apt install esl-erlang=1:20.3.6`

  - Install or provide access to an Ethereum node (e.g. [geth](https://github.com/ethereum/go-ethereum/wiki/geth))
  - If required, install the following packages:
    `sudo apt-get install build-essential autoconf libtool libgmp3-dev` -->

## Install prerequisite packages
```
sudo apt-get update
sudo apt-get -y install build-essential autoconf libtool libgmp3-dev libssl-dev
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
cd DEV
source bin/activate
```

## Install populus
[Ref](https://github.com/ethereum/populus/issues/450)
```
pip3 install populus
pip3 install eth-utils==0.8.1 web3==3.16.5
```
If an error is raised when installing the specific version of `eth-utils`, the error may be ignored for the purposes of this installation.

## Install solc 0.4.24
Note that solc 0.4.24 is required
```
python3 -m solc.install v0.4.24
```

## Install rebar
```
mix do local.hex --force, local.rebar --force
```
## Clone repo and build
```
# solc in the path is ignored. Explicitly specify path to binary
Export SOLC_BINARY=~/.py-solc/solc-v0.4.18/bin/solc

# populus requires character encoding to be set
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

git clone https://github.com/omisego/omisego
cd omisego
mix deps.get
```

## Check this works!
For a quick test (with no integration tests)
```
mix test --no-start
```

To run integration tests (requires compiling contracts)
```
mix test --no-start --only integration
```
