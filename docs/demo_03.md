# Load testing the child chain and Watcher

The following demo is a mix of commands executed in IEx (Elixir's) REPL (see README.md for instructions) and shell.

Run a developer's Child chain server, Watcher, and start IEx REPL with code and config loaded, as described in README.md instructions.

```elixir

### PREPARATIONS

# we're going to be using the exthereum's client to geth's JSON RPC
{:ok, _} = Application.ensure_all_started(:ethereumex)

alias OMG.{API, Eth}
alias OMG.API.Crypto
alias OMG.API.TestHelper

alice = TestHelper.generate_entity()

{:ok, alice_enc} = Eth.DevHelpers.import_unlock_fund(alice)

{:ok, contract_addr} = Application.get_env(:omg_eth, :contract_addr) |> Crypto.decode_address()

### START DEMO HERE

OMG.Performance.start_extended_perftest(10_000, [alice], contract_addr)


:os.cmd('cat #{result_file}') |> Poison.decode!
```
