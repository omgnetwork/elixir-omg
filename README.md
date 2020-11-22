<img src="docs/assets/logo.png" width="100" height="100" align="right" />

The `elixir-omg` repository contains OmiseGO's Elixir implementation of Plasma and forms the basis for the OMG Network.

[![Build Status](https://circleci.com/gh/omgnetwork/elixir-omg.svg?style=svg)](https://circleci.com/gh/omgnetwork/elixir-omg) [![Coverage Status](https://coveralls.io/repos/github/omisego/elixir-omg/badge.svg?branch=master)](https://coveralls.io/github/omisego/elixir-omg?branch=master)

**IMPORTANT NOTICE: Heavily WIP, expect anything**

**Table of Contents**

<!--ts-->
   * [Getting Started](#getting-started)
      * [Service start up using Docker Compose](#service-start-up-using-docker-compose)
         * [Troubleshooting Docker](#troubleshooting-docker)
       * [Install on a Linux host](#install-on-a-linux-host)
   * [Installing Plasma contract snapshots](#installing-plasma-contract-snapshots)
   * [Testing &amp; development](#testing--development)
   * [Working with API Spec's](#working-with-api-specs)

<!-- Added by: user, at: 2019-04-03T18:13+02:00 -->

<!--te-->

<!-- Created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc) -->
<!-- GH_TOC_TOKEN=75... ./gh-md-toc --insert ../omgnetwork/README.md -->

# Getting Started

A public testnet for the OMG Network is coming soon.
However, if you are brave and want to test being a Plasma chain operator, read on!

## Service start up using Docker Compose
This is the recommended method of starting the blockchain services, with the auxiliary services automatically provisioned through Docker.

Before attempting the start up please ensure that you are not running any services that are listening on the following TCP ports: 9656, 7434, 7534, 5000, 8545, 5432, 5433.
All commands should be run from the root of the repo.

To bring the entire system up you will first need to bring in the compatible Geth snapshot of plasma contracts:

```sh
make init_test
```
It creates a file `./localchain_contract_addresses.env`. It is required to have this file in current directory for running any `docker-compose` command.

```sh
docker-compose up
```

To bring only specific services up (eg: the childchain service, geth, etc...):

```sh
docker-compose up childchain geth ...
```

_(Note: This will also bring up any services childchain depends on.)_

To run a Watcher only, first make sure you sent an ENV variable called with `INFURA_API_KEY` with your api key and then run:

```sh
docker-compose -f docker-compose-watcher.yml up
```

### Troubleshooting Docker
You can view the running containers via `docker ps`

If service start up is unsuccessful, containers can be left hanging which impacts the start of services on the future attempts of `docker-compose up`.
You can stop all running containers via `docker kill $(docker ps -q)`.

If the blockchain services are not already present on the host, docker-compose will attempt to pull the latest build coming from master.
If you want Docker to use the latest commit from `elixir-omg` you can trigger a fresh build by building all three services with `make docker-childchain`, `make docker-watcher` and `make docker-watcher_info`.

# Install on a Linux host
Follow the guide to **[install](docs/install.md)** the Child Chain server, Watcher and Watcher Info.

# Installing Plasma contract snapshots

To pull in the compatible snapshot for Geth:
```bash
make init_test
```

# Testing & development

Docker building of source code and dependencies used to directly use common `mix` folders like `_build` and `deps`. To support workflows that switch between bare metal and Docker containers we've introduced `_build_docker` and `deps_docker` folders:

```sh
sudo rm -rf _build_docker
sudo rm -rf deps_docker

mkdir _build_docker && chmod 777 _build_docker
mkdir deps_docker && chmod 777 deps_docker
```

Pull in the compatible Plasma contracts snapshot:
```bash
make init_test
```

You can setup the docker environment to run testing and development tasks:

```sh
docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.datadog.yml run --rm --entrypoint bash elixir-omg
```

Once the shell has loaded, you can continue and run additional tasks.

Get the necessary dependencies for building:
```bash
cd app && mix deps.get
```

Quick test (no integration tests):
```bash
mix test
```

Longer-running integration tests (requires compiling contracts):
```bash
mix test --trace --only integration
```

For other kinds of checks, refer to the CI/CD pipeline (https://circleci.com/gh/omisego/workflows/elixir-omg) or build steps (https://github.com/omisego/elixir-omg/blob/master/.circleci/config.yml).

To run a development `iex` REPL with all code loaded:
```bash
MIX_ENV=test iex -S mix run --no-start
```

## Running integration cabbage tests

Integration tests are written using the [`cabbage`](https://github.com/cabbage-ex/cabbage) library and they are located in a separated repo - [specs](https://github.com/omgnetwork/specs). This repo is added to `elixir-omg` as a git submodule. So to fetch them run:
```bash
git submodule init
git submodule update --remote
```

Create a directory for geth:
```bash
mkdir data && chmod 777 data
```

Make services:
```bash
make docker-watcher
make docker-watcher_info
```

Start geth and postgres:
```bash
cd priv/cabbage
make start_daemon_services-2
```

If the above command fails with the message similar to:
```
Creating network "omisego_chain_net" with driver "bridge"
ERROR: Pool overlaps with other one on this address space
```

try the following remedy and retry:
```bash
make stop_daemon_services
rm -rf ../../data/*
docker network prune
```


Build the integration tests project and run tests:
```bash
cd priv/cabbage
make install
make generate_api_code
mix deps.get
mix test
```

## Running reorg cabbage tests

Reorg tests test different assumptions against chain reorgs. They also use the same submodule as regular integration cabbage tests.

Fetch submodule:
```bash
git submodule init
git submodule update --remote
```

Create a directory for geth nodes:
```bash
mkdir data1 && chmod 777 data1 && mkdir data2 && chmod 777 data2 && mkdir data && chmod 777 data
```

Make services:
```bash
make docker-watcher
make docker-watcher_info
```

Start geth nodes and postgres:
```bash
cd priv/cabbage
make start_daemon_services_reorg-2
```

Build the integration tests project and run reorg tests:
```bash
cd priv/cabbage
make install
make generate_api_code
mix deps.get
REORG=true mix test --only reorg --trace
```

# Working with API Spec's

This repo contains `gh-pages` branch intended to host [Swagger-based](https://docs.omg.network/elixir-omg/) API specification.
Branch `gh-pages` is totally diseparated from other development branches and contains just Slate generated page's files.

See [gh-pages README](https://github.com/omisego/elixir-omg/tree/gh-pages) for more details.

# More details about the design and architecture

Details about the repository, code, architecture and design decisions are available **[here](docs/details.md)**.
