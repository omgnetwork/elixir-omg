# OmiseGO

For the child chain server, see [apps/omisego_api](apps/omisego_api).

For the watcher, see [apps/omisego_watcher](apps/omisego_watcher).

For generic information, keep on reading.

**IMPORTANT NOTICE: Heavily WIP, expect anything**

## Installation

**NOTE**: Currently the child chain server and watcher are bundled within a single umbrella app.

### Prerequisites

Only **Linux** platforms supported now. Known to work with Ubuntu 16.04

  - Install [Elixir](http://elixir-lang.github.io/install.html#unix-and-unix-like).
    Make sure `rebar` is in your path, e.g. `mix do local.hex --force, local.rebar --force`
  - Install or provide access to an Ethereum node (e.g. [geth](https://github.com/ethereum/go-ethereum/wiki/geth))

### OmiseGO child chain server and watcher

**TODO** hex-ify the package.

  - `git clone https://github.com/omisego/omisego` - clone this repo
  - `cd omisego`
  - `mix deps.get`
  - If you want to compile/test/deploy contracts see `populus/README.md` for instructions

## Testing & development

  - quick test (no integration tests): `mix test --no-start`
  - longer-running integration tests: `mix test --no-start --only integration` (requires compiling contracts)

For other kinds of checks, refer to the CI/CD pipeline (`Jenkinsfile`).

  - to run a development `iex` REPL with all code loaded: `iex -S mix run --no-start`
