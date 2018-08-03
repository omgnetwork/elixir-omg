# Troubleshooting
## Configuring the omisego_eth app fails with error
```
** (MatchError) no match of right hand side value: {:error, :econnrefused}
    lib/eth/dev_helpers.ex:44: OmiseGO.Eth.DevHelpers.create_and_fund_authority_addr/0
    lib/eth/dev_helpers.ex:11: OmiseGO.Eth.DevHelpers.prepare_env!/1
    (stdlib) erl_eval.erl:670: :erl_eval.do_apply/6
    (stdlib) erl_eval.erl:878: :erl_eval.expr_list/6
    (stdlib) erl_eval.erl:404: :erl_eval.expr/5
    (elixir) lib/code.ex:192: Code.eval_string/3
    (elixir) lib/enum.ex:737: Enum."-each/2-lists^foreach/1-0-"/2
    (elixir) lib/enum.ex:737: Enum.each/2
    (mix) lib/mix/tasks/run.ex:132: Mix.Tasks.Run.run/5
    (mix) lib/mix/tasks/run.ex:76: Mix.Tasks.Run.run/1
    (mix) lib/mix/task.ex:314: Mix.Task.run_task/3
    (mix) lib/mix/cli.ex:80: Mix.CLI.run_task/2
    (elixir) lib/code.ex:677: Code.require_file/2
```

Answer: Ensure that the dev Ethereum instance is running: geth

## Error starting child chain server
```
** (Mix) Could not start application omisego_api: OmiseGO.API.Application.start(:normal, []) returned an error: shutdown: failed to start child: OmiseGO.API.BlockQueue.Server
    ** (EXIT) an exception was raised:
        ** (MatchError) no match of right hand side value: {:error, :mined_blknum_not_found_in_db}
            (omisego_api) lib/block_queue.ex:78: OmiseGO.API.BlockQueue.Server.init/1
            (stdlib) gen_server.erl:365: :gen_server.init_it/2
            (stdlib) gen_server.erl:333: :gen_server.init_it/6
            (stdlib) proc_lib.erl:247: :proc_lib.init_p_do_apply/3
```

Answer:
rm -rf ~/.omisego

## Error starting child chain server
```
22:44:32.024 [info] Started BlockQueue
22:44:32.068 [error] GenServer OmiseGO.API.BlockQueue.Server terminating
** (CaseClauseError) no case clause matching: {:error, %{"code" => -32000, "message" => "authentication needed: password or unlock"}}
    (omisego_api) lib/block_queue.ex:139: OmiseGO.API.BlockQueue.Server.submit/1
    (elixir) lib/enum.ex:737: Enum."-each/2-lists^foreach/1-0-"/2
    (elixir) lib/enum.ex:737: Enum.each/2
    (omisego_api) lib/block_queue.ex:101: OmiseGO.API.BlockQueue.Server.handle_info/2
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

## Error Starting child chain server
```
** (Mix) Could not start application omisego_api: OmiseGO.API.Application.start(:normal, []) returned an error: shutdown: failed to start child: OmiseGO.API.State
    ** (EXIT) an exception was raised:
        ** (ArithmeticError) bad argument in arithmetic expression
            (omisego_api) lib/state/core.ex:30: OmiseGO.API.State.Core.extract_initial_state/4
            (omisego_api) lib/state.ex:70: OmiseGO.API.State.init/1
            (stdlib) gen_server.erl:365: :gen_server.init_it/2mix d
            (stdlib) gen_server.erl:333: :gen_server.init_it/6
            (stdlib) proc_lib.erl:247: :proc_lib.init_p_do_apply/3
```
Answer:
Child chain database not initialized yet

## To compile or recompile the contracts
```
mix deps.compile plasma_contract
```

## To re-activate the virtualenv
```
cd ~
source DEV/bin/activate
```
