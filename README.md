<img src="docs/assets/logo.png" align="right" />

The `elixir-omg` repository contains OmiseGO's Elixir implementation of Plasma and forms the basis for the OMG Network.

[![Build Status](https://circleci.com/gh/omisego/elixir-omg.svg?style=svg)](https://circleci.com/gh/omisego/elixir-omg) [![Coverage Status](https://coveralls.io/repos/github/omisego/elixir-omg/badge.svg?branch=master)](https://coveralls.io/github/omisego/elixir-omg?branch=master) [![Gitter chat](https://badges.gitter.im/omisego/elixir-omg.png)](https://gitter.im/omisego/elixir-omg)

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
<!-- GH_TOC_TOKEN=75... ./gh-md-toc --insert ../omisego/README.md -->

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

Docker building of source code and dependencies used to directly use common `mix` folders like `_build` and `deps`. To support workflows that switch between bare metal and Docker containers we've introduced `_build_docker` and `deps_docker` folders.

You can setup the docker environment to run testing and development tasks:

```sh
docker-compose -f docker-compose.yml -f docker-compose.dev.yml run --rm --entrypoint bash elixir-omg
```

Once the shell has loaded, you can continue and run additional tasks.

Get the necessary dependencies for building:
```bash
mix deps.get
```

Pull in the compatible Plasma contracts snapshot:
```bash
make init_test
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

# Working with API Spec's

This repo contains `gh-pages` branch intended to host [Swagger-based](https://developer.omisego.co/elixir-omg/) API specification.
Branch `gh-pages` is totally diseparated from other development branches and contains just Slate generated page's files.

See [gh-pages README](https://github.com/omisego/elixir-omg/blob/gh-pages/docs/api_specs/README.md) for more details.

# More details about the design and arhitecture

Details about the repository, code, arhitecture and design decisions are available **[here](docs/details.md)**.
