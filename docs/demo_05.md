# Load testing the child chain and Watcher

The following demo is a mix of commands executed in IEx (Elixir's) REPL (see [manual startup](/docs/manual_service_startup.md) for instructions) and shell.

Follow the [docs/demo_03.md](/docs/demo_03.md) to run a developer's Child chain server, Watcher and fill a testnet with noticable amount of transactions by running `start_extended_perftest`.

In the elixir REPL continue with
```elixir

### PREPARATIONS

alias OMG.Eth
alias OMG.Performance
alias OMG.Performance.ByzantineEvents

{:ok, _} = Application.ensure_all_started(:hackney)
contract_addr = Application.fetch_env!(:omg_eth, :contract_addr) |> Eth.RootChain.contract_map_from_hex()

exiting_users = 5

### START DEMO HERE

# wait before asking watcher about exit data
ByzantineEvents.watcher_synchronize()

Performance.start_standard_exit_perftest(alices, exiting_users, contract_addr)
```
