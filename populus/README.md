# Installing `populus` and compiling contracts

**Python3 is required**, [`virtualenv`](https://virtualenv.pypa.io/en/stable/) is recommended.

To install populus and solc 0.4.18
```bash
sudo apt-get install libssl-dev
pip install -r populus/requirements.txt
python -m solc.install v0.4.18
```

Contracts will compile automatically as a regular mix dependency.
To compile contracts manually:
```
mix deps.compile plasma_mvp_contracts
```

**DEV NOTE** `requirements.txt` is the frozen set of versioned dependencies, effect of running
```bash
pip install -r requirements-to-freeze.txt && pip freeze | grep -v ^pkg-resources > requirements.txt
```
see [a better pip workflow^TM here](https://www.kennethreitz.org/essays/a-better-pip-workflow) for rationale.

**DEV NOTE** removing `pkg-resources` comes from [here](https://stackoverflow.com/a/48365609)
