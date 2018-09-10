# Troubleshooting

**TODO** - remove these hints and return meaningful error messages instead, wherever possible

## Error starting child chain server
```
** (Mix) Could not start application omg_api: OMG.API.Application.start(:normal, []) returned an error: shutdown: failed to start child: OMG.API.BlockQueue.Server
    ** (EXIT) an exception was raised:
        ** (MatchError) no match of right hand side value: {:error, :mined_blknum_not_found_in_db}
            (omg_api) lib/block_queue.ex:78: OMG.API.BlockQueue.Server.init/1
            (stdlib) gen_server.erl:365: :gen_server.init_it/2
            (stdlib) gen_server.erl:333: :gen_server.init_it/6
            (stdlib) proc_lib.erl:247: :proc_lib.init_p_do_apply/3
```

The child chain might have not been wiped clean when starting a child chain from scratch.
Answer: follow the setting up of developer environment from the beginning.

## Error starting child chain server
```
22:44:32.024 [info] Started BlockQueue
22:44:32.068 [error] GenServer OMG.API.BlockQueue.Server terminating
** (CaseClauseError) no case clause matching: {:error, %{"code" => -32000, "message" => "authentication needed: password or unlock"}}
    (omg_api) lib/block_queue.ex:139: OMG.API.BlockQueue.Server.submit/1
    (elixir) lib/enum.ex:737: Enum."-each/2-lists^foreach/1-0-"/2
    (elixir) lib/enum.ex:737: Enum.each/2
    (omg_api) lib/block_queue.ex:101: OMG.API.BlockQueue.Server.handle_info/2
    (stdlib) gen_server.erl:616: :gen_server.try_dispatch/4
    (stdlib) gen_server.erl:686: :gen_server.handle_msg/6
    (stdlib) proc_lib.erl:247: :proc_lib.init_p_do_apply/3
Last message: :check_mined_child_head
```
Answer:
Unlock the authority account.

```
geth attach http://127.0.0.1:8545
personal.unlockAccount(“<authority_addr from config.exs>”, '', 0)
```

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
