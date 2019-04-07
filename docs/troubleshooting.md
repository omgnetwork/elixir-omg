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

## To compile or recompile the contracts
```
mix deps.compile plasma_contracts
```
