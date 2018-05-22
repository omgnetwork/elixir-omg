# Source Consumption Log

### About:

Identifies each module of pre-existing source code used in developing source code, what license (if any) that source code was provided under, where the preexisting source code and the license can be obtained publicly (if so available), and identification of where that source is located.

## Redistributed already

* Elixir/Erlang/BEAM/OTP
  * `Elixir`, Apache 2.0, https://github.com/elixir-lang/elixir
  * `Erlang`, Apache 2.0, https://www.erlang.org
  * `BEAM/OTP`, Apache 2.0, https://github.com/erlang/otp
* MIX deps, as listed by the `mix.exs` files of applications in `omisego` repo
  * `credo`, MIT, https://hex.pm/packages/credo
  * `dialyxir`, Apache 2.0, https://hex.pm/packages/dialyxir
  * `ex_unit_fixtures`, MIT, https://hex.pm/packages/ex_unit_fixtures
  * `jsonrpc2`, Apache 2.0, https://hex.pm/packages/jsonrpc2
  * `poison`, CC0-1.0, https://hex.pm/packages/poison
  * `excoveralls`, MIT, https://hex.pm/packages/excoveralls
  * `phoenix_pubsub`, MIT, https://hex.pm/packages/phoenix_pubsub
  * `ex_rlp`, MIT, https://hex.pm/packages/ex_rlp
  * `blockchain`, MIT, https://hex.pm/packages/blockchain
  * `libsecp256k1`, MIT, https://hex.pm/packages/libsecp256k1
  * `exleveldb`, Apache 2.0, https://hex.pm/packages/exleveldb
  * `merkle_tree`, MIT, https://hex.pm/packages/merkle_tree
  * `abi`, MIT , https://github.com/omisego/abi.git
  * `temp`, MIT, https://hex.pm/packages/temp
  * `ethereumex`, MIT, https://github.com/omisego/ethereumex.git
  * `phoenix`, MIT, https://github.com/phoenixframework/phoenix
  * `phoenix_ecto`, MIT, https://github.com/phoenixframework/phoenix_ecto
  * `gettext`, Apache 2.0, https://github.com/elixir-lang/gettext
  * `postgrex`, Apache 2.0, https://github.com/elixir-ecto/postgrex
  * `sqlite_ecto2`, MIT, https://github.com/scouten/sqlite_ecto2
  * `cowboy`, ISC License, https://github.com/ninenines/cowboy
  * `cowlib`, ISC License, https://github.com/ninenines/cowlib
  * `ranch`, ISC License, https://github.com/ninenines/ranch 
  * `erlexec`, BSD license, https://github.com/saleyn/erlexec
  * `briefly`, Apache 2.0, https://github.com/CargoSense/briefly/


## Likely to be redistributed

* MIX deps...
  * <non yet>
* `geth`, LGPL 3.0, https://github.com/ethereum/go-ethereum, (used via an interface, so ok)
* `zeppelin-solidity`, MIT, https://github.com/OpenZeppelin/zeppelin-solidity

## Likely to be used, but not redistributed

* `populus/web3.py/et al.`, MIT, https://pypi.python.org/pypi/populus/1.11.0
* `solc`, GPL 3.0, https://github.com/ethereum/solidity
* `postgresql`, PostgreSQL License, https://www.postgresql.org
