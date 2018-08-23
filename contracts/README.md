# Contracts

OMG network uses contract code from [the contracts repo](github.com/omisego/plasma-contracts).
Code from a particular branch in that repo is used, see [one of `mix.exs` configuration files](`../apps/omg_eth/mix.exs`) for details.

Contract code is downloaded automatically when getting dependencies of the Mix application.
You can find the downloaded version of that code under `deps/plasma_contracts`.

## Installing dependencies and compiling contracts

**Python3 is required**, [`virtualenv`](https://virtualenv.pypa.io/en/stable/) is recommended.

To install dependencies:
```bash
sudo apt-get install libssl-dev solc
pip install -r contracts/requirements.txt
```

Contracts will compile automatically as a regular mix dependency.
To compile contracts manually:
```
mix deps.compile plasma_contracts
```

**DEV NOTE** `requirements.txt` is the frozen set of versioned dependencies, effect of running
```bash
pip install -r requirements-to-freeze.txt && pip freeze | grep -v ^pkg-resources > requirements.txt
```
see [a better pip workflow^TM here](https://www.kennethreitz.org/essays/a-better-pip-workflow) for rationale.

**DEV NOTE** removing `pkg-resources` comes from [here](https://stackoverflow.com/a/48365609)
