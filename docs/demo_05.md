# Load testing the child chain and Watcher

The following demo is a mix of commands executed in IEx (Elixir's) REPL (see README.md for instructions) and shell.

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

import OMG.Performance.ByzantineEvents.Generators
import OMG.Performance.ByzantineEvents

alias OMG.Eth
alias OMG.Performance
 
DeferredConfig.populate(:omg_eth)

contract_addr = Application.fetch_env!(:omg_eth, :contract_addr) |> Eth.Encoding.from_hex()

# defaults
opts = [initial_funds: trunc(:math.pow(10, 18)) * 1]

# modify and execute for custom configuration
####
# configure to the source of test ether
# faucet =
# opts = Keyword.put(opts, :faucet, faucet)
# that has at least #alices times this to spare
# initial_funds_eth =
# opts = Keyword.put(opts, :initial_funds, trunc(:math.pow(10, 18) * initial_funds_eth))
####

dos_users = 2
ntx_to_send = 10
spenders = generate_users(1)
exit_per_dos = length(spenders) * ntx_to_send
total_exits = length(spenders) * ntx_to_send * dos_users

### START DEMO HERE

OMG.Performance.start_extended_perftest(ntx_to_send, spenders, contract_addr)

#get exit position from child chain
exit_positions = ByzantineEvents.stream_utxo_positions() |> Enum.take(exit_per_dos)

binary_txs = stream_txs() |> Enum.take(exit_per_dos)
utxos =  spenders |> Enum.map( fn spender -> get_exitable_utxos(spender) end ) |> Enum.concat()

#wait before asking watcher about exit data
watcher_synchronize()

start_dos_get_exits(dos_users, exit_positions)
start_dos_non_canonical_ife(dos_users, binary_txs, utxos, spenders)
```
