# Source Consumption Log

### About:

Identifies each module of pre-existing source code used in developing source code, what license (if any) that source code was provided under, where the preexisting source code and the license can be obtained publicly (if so available), and identification of where that source is located.

## Redistributed already

* Elixir/Erlang/BEAM/OTP
  * `Elixir`, Apache 2.0, https://github.com/elixir-lang/elixir
  * `Erlang`, Apache 2.0, https://www.erlang.org
  * `BEAM/OTP`, Apache 2.0, https://github.com/erlang/otp
* MIX deps, as listed `mix licenses` ([licensir](https://github.com/unnawut/licensir/)), cleaned/completed manually.
**NOTE**, unless otherwise noted, package is obtained from `hex.pm/packages/<package_name>`:
```
abi 0.1.12              -> MIT
binary 0.0.4            -> MIT
blockchain 0.1.7        -> MIT
bunt 0.2.0              -> MIT
briefly 0.3.0           -> Apache 2.0
certifi 2.3.1           -> BSD
cowboy 1.1.2            -> ISC
cowlib 1.0.2            -> ISC
credo 0.9.3             -> MIT
db_connection 1.1.3     -> Apache 2.0
decimal 1.5.0           -> Apache 2.0
dialyxir 1.0.0-rc.6     -> Apache 2.0
ecto 3.1.5              -> Apache 2.0
erlang-rocksdb 1.2.0    -> Apache 2.0
erlexec 1.7.5           -> BSD
ethereumex 0.5.4        -> MIT
ex_rlp 0.5.2            -> MIT
ex_unit_fixtures        -> MIT
exexec 0.1.0            -> Apache 2.0
exth_crypto 0.1.4       -> MIT
fake_server 1.5.0       -> Apache 2.0
hackney 1.15.1          -> Apache 2
httpoison 1.6.0         -> MIT
idna 5.1.1              -> BSD
keccakf1600 2.0.0       -> MPL 2.0 (ok'd by legal, compliant with our Apache 2.0)
libsecp256k1 0.1.9      -> MIT
licensir 0.2.7          -> MIT
merkle_patricia_tree 0.2.6-> MIT
merkle_tree 1.5.0       -> MIT
metrics 1.0.1           -> BSD
mime 1.3.0              -> Apache 2
mimerl 1.0.2            -> MIT
parse_trans 3.2.0       -> Apache 2.0
phoenix 1.3.2           -> MIT
phoenix_ecto 3.3.0      -> Apache 2.0
phoenix_pubsub 1.0.2    -> MIT
plug 1.5.0              -> Apache 2
poison 3.1.0            -> CC0-1.0 (ok'd by legal, compliant with our Apache 2.0)
postgrex 0.13.5         -> Apache 2.0
ranch 1.3.2             -> ISC
poolboy 1.5.1           -> Apache 2.0
socket 0.3.13           -> WTFPL
ssl_verify_fun 1.1.1    -> MIT
unicode_util_compat 0.3.1-> Apache 2.0
```

## Likely to be redistributed

* `geth`, LGPL 3.0, https://github.com/ethereum/go-ethereum, (used via an interface, so ok)
* `zeppelin-solidity`, MIT, https://github.com/OpenZeppelin/zeppelin-solidity

## Likely to be used, but not redistributed

* `web3`, MIT, https://github.com/ethereum/web3.py
* `ethereum`, MIT, https://github.com/ethereum/pyethereum
* `rlp`, MIT, https://github.com/ethereum/pyrlp
* `py-solc`, MIT, https://github.com/ethereum/py-solc
* `solc`, GPL 3.0, https://github.com/ethereum/solidity
* `postgresql`, PostgreSQL License, https://www.postgresql.org

