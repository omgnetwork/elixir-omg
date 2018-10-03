# Troubleshooting

**TODO** - remove these hints and return meaningful error messages instead, wherever possible

## Error compiling contracts

```
    > command: `solc --allow-paths /elixir-omg/deps/plasma_contracts/contracts --standard-json`
    > return code: `0`
    > stderr:
    {"contracts":{},"errors":[{"component":"general","formattedMessage":"RootChain.sol:92:16: ParserError: Expected identifier, got 'LParen'\n    constructor(
)\n               ^\n","message":"Expected identifier, got 'LParen'","severity":"error","type":"ParserError"}],"sources":{}}
```

Answer:
Ensure `solc` is at at least the required version (see [installation instructions](./install.md)).

## Error compiling contracts

```
** (Mix) Could not compile dependency :plasma_contracts, "cd elixir-omg/apps/omg_eth/../../ && py-solc-simple -i deps/plasma_con
tracts/contracts/ -o contracts/build/" command failed. You can recompile this dependency with "mix deps.compile plasma_contracts", update it with "mix deps.up
date plasma_contracts" or clean it with "mix deps.clean plasma_contracts"
```

Answer: [install the contract building machinery](./install.md#install-contract-building-machinery)


## To compile or recompile the contracts
```
mix deps.compile plasma_contract
```

## To re-activate the virtualenv
```
cd ~
source DEV/bin/activate
```
