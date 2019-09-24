# Load testing the child chain and Watcher

The following demo is a mix of commands executed in IEx (Elixir's) REPL (see [manual startup](/docs/manual_service_startup.md) for instructions) and shell.

Follow the [docs/demo_03.md](/docs/demo_03.md) to run a developer's Child chain server, Watcher and fill a testnet with noticable amount of transactions with running perftest.

In the elixir REPL continue with
```elixir

### PREPARATIONS

alias OMG.Performance.ByzantineEvents
alias OMG.Performance.ByzantineEvents.Generators
 
dos_users = 5
exit_per_dos = 10

### START DEMO HERE

# get exit position from child chain
exit_positions = Generators.stream_utxo_positions() |> Enum.take(exit_per_dos)

# wait before asking watcher about exit data
ByzantineEvents.watcher_synchronize()

ByzantineEvents.start_dos_get_exits(exit_positions, dos_users)
```
