# Installing dependencies and compiling contracts

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
