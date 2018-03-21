# Populus readme

to install populus and solc 0.4.18
```
sudo apt-get install libssl-dev
cd populus
pip install -r requirements.txt
python -m solc.install v0.4.18
```

to compile contracts
```
SOLC_BINARY=${HOME}/.py-solc/solc-v0.4.18/bin/solc populus compile
```
