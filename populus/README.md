# Installing `populus` and compiling contracts

**Python3 is required**, [`virtualenv`](https://virtualenv.pypa.io/en/stable/) is recommended.

To install populus and solc 0.4.18
```bash
sudo apt-get install libssl-dev
cd populus
pip install -r requirements.txt
python -m solc.install v0.4.18
```

To compile contracts
```
SOLC_BINARY=${HOME}/.py-solc/solc-v0.4.18/bin/solc populus compile
```

**DEV NOTE** `requirements.txt` is the frozen set of versioned dependencies, effect of running
```bash
pip install -r requirements-to-freeze.txt && pip freeze | grep -v ^pkg-resources > requirements.txt
```
see [a better pip workflow^TM here](https://www.kennethreitz.org/essays/a-better-pip-workflow) for rationale.

**DEV NOTE** removing `pkg-resources` comes from [here](https://stackoverflow.com/a/48365609)
