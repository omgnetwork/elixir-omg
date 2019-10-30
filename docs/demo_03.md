# Load testing the child chain and Watcher

The following demo is a mix of commands executed in IEx (Elixir's) REPL (see [manual startup](/docs/manual_service_startup.md) for instructions) and shell.

Run a developer's Child chain server, Watcher, and start IEx REPL with code and config loaded, as described in README.md instructions.

**NOTE** It's advisable to adjust the processing of deposits like so (in your `~/config.exs`):
```
config :omg,
  deposit_finality_margin: 1,
  ethereum_status_check_interval_ms: 100

config :omg_child_chain,
  exiters_finality_margin: 2,
```
Otherwise one might experience a long wait before the child chain allows the deposits to be spent (which every invocation of `start_extended_perftest` waits for).

Run `iex -S mix run --no-start --config ~/config.exs` and inside REPL do:

```elixir

### PREPARATIONS

# we're going to be using the exthereum's client to geth's JSON RPC
{:ok, _} = Application.ensure_all_started(:ethereumex)

alias OMG.Eth
alias OMG.TestHelper

contract_addr = Application.fetch_env!(:omg_eth, :contract_addr) |> Eth.Encoding.from_hex()

# defaults
opts = [initial_funds: trunc(:math.pow(10, 18)) * 1]

# modify and execute for custom configuration
####
# configure to the source of test ether
faucet =
opts = Keyword.put(opts, :faucet, faucet)
# that has at least #alices times this to spare
initial_funds_eth =
opts = Keyword.put(opts, :initial_funds, trunc(:math.pow(10, 18) * initial_funds_eth))
####

generate = fn ->
  alice = TestHelper.generate_entity()

  {:ok, _alice_enc} = Support.DevHelper.import_unlock_fund(alice, opts)
  alice
end

alices = 1..5 |> Enum.map(fn _ -> Task.async(generate) end) |> Enum.map(& Task.await(&1, :infinity))
### START DEMO HERE

OMG.Performance.start_extended_perftest(10_000, alices, contract_addr)


:os.cmd('cat #{result_file}') |> Jason.decode!
```
