# Load testing the child chain and Watcher

The following demo is a mix of commands executed in IEx (Elixir's) REPL (see README.md for instructions) and shell.

Run a developer's Child chain server, Watcher, and start IEx REPL with code and config loaded, as described in README.md instructions.

**NOTE** It's advisable to adjust the processing of deposits like so (in your `~/config.exs`):
```
config :omg_api,
  ethereum_event_block_finality_margin: 1,
  ethereum_event_check_height_interval_ms: 100
```
Otherwise one might experience a long wait before the child chain allows the deposits to be spent (which every invocation of `start_extended_perftest` waits for).

Run `cd apps/omg_performance && iex -S mix run --config ~/config.exs` and inside REPL do:

```elixir

### PREPARATIONS

# we're going to be using the exthereum's client to geth's JSON RPC
{:ok, _} = Application.ensure_all_started(:ethereumex)

alias OMG.{API, Eth}
alias OMG.API.Crypto
alias OMG.API.TestHelper

{:ok, contract_addr} = Application.get_env(:omg_eth, :contract_addr) |> Crypto.decode_address()

generate = fn ->
  alice = TestHelper.generate_entity()

  {:ok, _alice_enc} = Eth.DevHelpers.import_unlock_fund(alice)
  alice
end

alices = 1..5 |> Enum.map(fn _ -> Task.async(generate) end) |> Enum.map(& Task.await(&1, :infinity))
### START DEMO HERE

OMG.Performance.start_extended_perftest(10_000, alices, contract_addr)


:os.cmd('cat #{result_file}') |> Poison.decode!
```
