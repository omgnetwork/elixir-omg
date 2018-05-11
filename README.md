# OmiseGO

FIXME this: See `make help -f Makefile.example` for some help

For child chain server specific `README.md` see `apps/omisego_api`
For watcher specific `README.md` see `apps/omisego_watcher`
For generic information, keep on reading.

## IMPORTANT NOTICE

**Heavily WIP, expect anything**

## Installation

**NOTE**: Currently the child chain server and watcher are bundled within a single umbrella app.

### Prerequisites

Only **Linux** platforms supported now. Known to work with Ubuntu 16.04

Install [Elixir](http://elixir-lang.github.io/install.html#unix-and-unix-like).
Make sure `rebar` is in your path, e.g. `export PATH=$PATH:~/.mix` (mileage may vary).

Install or provide access to an Ethereum node (e.g. [geth](https://github.com/ethereum/go-ethereum/wiki/geth)).

### OmiseGO child chain server and watcher

**TODO** hex-ify the package.

  - `git clone github.com/omisego/omisego omisego` - clone this repo
  - `cd omisego`
  - `mix deps.get`
  - if you want to compile/test/deploy contracts see `populus/README.md` for instructions

## Testing

 - quick test (no integration tests): `mix test --no-start`
 - longer-running integration tests: `mix test --no-start --only integration` (requires compiling contracts)
 - watcher integration tests: `mix test --only watcher_tests`

For other kinds of checks, refer to our CI/CD pipeline (`Jenkinsfile`).
