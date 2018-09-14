# Watching a valid and invalid child chain

The following demo is a mix of commands executed in IEx and some Unix shell.

Run a developer's Child chain server, Watcher and start IEx REPL with code and config loaded, as described in README.md instructions.

**NOTE** you'll find it useful to run the child chain server with a IEx to recompile:
        iex -S mix run --config ...


```elixir

### PREPARATIONS

# we're going to be using the exthereum's client to geth's JSON RPC
{:ok, _} = Application.ensure_all_started(:ethereumex)

alias OMG.{API, Eth}
alias OMG.API.Crypto
alias OMG.API.State.Transaction
alias OMG.API.TestHelper

alice = TestHelper.generate_entity()
bob = TestHelper.generate_entity()
eth = Crypto.zero_address()

{:ok, _} = Eth.DevHelpers.import_unlock_fund(alice)
{:ok, _} = Eth.DevHelpers.import_unlock_fund(bob)

# sends a deposit transaction _to Ethereum_
{:ok, deposit_tx_hash} = Eth.RootChain.deposit(10, bob.addr)
{:ok, deposit_tx_hash} = Eth.RootChain.deposit(10, alice.addr)

{:ok, alice_enc} = Crypto.encode_address(alice.addr)
{:ok, bob_enc} = Crypto.encode_address(bob.addr)

# need to wait until it's mined
{:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)

# we need to uncover the height at which the deposit went through on the root chain
# to do this, look in the logs inside the receipt printed just above
deposit_blknum = Eth.RootChain.deposit_blknum_from_receipt(receipt)

### START DEMO HERE

# we've got alice, bob prepared, also an honest child chain is running with a watcher connected
# NOTE: if you stopped and started geth after setting up alice and bob you need to unlock their accounts
#       e.g. in shell `geth attach http://localhost:8545` then `personal.unlockAccount(alice_enc, "", 0)`

# 1/ Demonstrate Watcher consuming honest transactions

# create and prepare transaction for signing
tx =
  Transaction.new([{deposit_blknum, 0, 0}], eth, [{bob.addr, 7}, {alice.addr, 3}]) |>
  Transaction.sign(alice.priv, <<>>) |>
  Transaction.Signed.encode() |>
  Base.encode16()

```

```bash
# submits a transaction to the child chain
# this only will work after the deposit has been "consumed" by the child chain, be patient (~15sec)
# use the hex-encoded tx bytes and `submit` JSONRPC method described in README.md for child chain server
# in the following json use `tx` value in "transaction" field

curl "localhost:9656" -d '{"params":{"transaction": ""}, "method": "submit", "jsonrpc": "2.0","id":0}'

# see the Watcher getting a 1-txs block
```

```elixir

# 2/ Using the Watcher

# grab the first transaction hash as returned by the Child chain server's API (response to `curl`'s request)
tx1_hash =

"http GET 'localhost:4000/transaction/#{tx1_hash}'" |>
to_charlist() |>
:os.cmd() |>
Poison.decode!()

%{"data" => %{"utxos" => [%{"blknum" => exiting_utxo_blknum, "txindex" => 0, "oindex" => 0}]}} =
  "http GET 'localhost:4000/utxos?address=#{bob_enc}'" |>
  to_charlist() |>
  :os.cmd() |>
  Poison.decode!()

# 3/ Exiting, challenging invalid exits

exiting_utxopos = OMG.API.Utxo.Position.encode({:utxo_position, exiting_utxo_blknum, 0, 0})

%{"data" => composed_exit} =
  "http GET 'localhost:4000/utxo/#{exiting_utxopos}/exit_data'" |>
  to_charlist() |>
  :os.cmd() |>
  Poison.decode!()

tx2 =
  Transaction.new([{exiting_utxo_blknum, 0, 0}], eth, [{bob.addr, 7}]) |>
  Transaction.sign(bob.priv, <<>>) |>
  Transaction.Signed.encode() |>
  Base.encode16()

# FIRST you need to spend in transaction as above, so that the exit then is in fact invalid and challengeable

{:ok, txhash} =
  Eth.RootChain.start_exit(
    composed_exit["utxo_pos"],
    Base.decode16!(composed_exit["txbytes"]),
    Base.decode16!(composed_exit["proof"]),
    Base.decode16!(composed_exit["sigs"]),
    bob.addr
  )
Eth.WaitFor.eth_receipt(txhash)

%{"data" => challenge} =
  "http GET 'localhost:4000/utxo/#{exiting_utxopos}/challenge_data'" |>
  to_charlist() |>
  :os.cmd() |>
  Poison.decode!()

{:ok, txhash} =
  OMG.Eth.RootChain.challenge_exit(
    challenge["cutxopos"],
    challenge["eutxoindex"],
    Base.decode16!(challenge["txbytes"]),
    Base.decode16!(challenge["proof"]),
    Base.decode16!(challenge["sigs"]),
    alice.addr
  )

{:ok, _} = Eth.WaitFor.eth_receipt(txhash)

# 4/ let's introduce a delay into the process of getting child block contents from the child chain server

# If we introduce a 5 second sleep, the Watcher will have a hard time getting a block (requests time out in 5 seconds).
# Some attempts will pass, some will fail and with the withholding threshold set to 10 seconds, we'll have block withholding stop the Watcher and print out an error (and fire events for machines)

# put `Process.sleep 5_000` in API module, around line 69

# now, with the code "broken" go to the `iex` REPL of the child chain and recompile the module

r(OMG.API)

# see Watcher's console logs to see the struggle and final give-in. You can restart the Watcher many times

# when you're done, undo the breakage and recompile again. Running the Watcher should allow it to sync

# 5/ invalid block submitted

# let's break the Child chain now and say that duplicates every transaction submitted!

# in order to do that, you need to duplicate the `|> add_pending_tx(recovered_tx)` in API.State.Core module,
# around line 123

# now, with the code "broken" go to the `iex` REPL of the child chain and recompile the module

r(OMG.API.State.Core)

# let's do a broken spend:

# grab a utxo that bob can spend
%{"data" => %{"utxos" => [%{"blknum" => spend_blknum, "txindex" => 0, "oindex" => 0}]}} =
  "http GET 'localhost:4000/utxos?address=#{bob_enc}'" |>
  to_charlist() |>
  :os.cmd() |>
  Poison.decode!()

tx2 =
  Transaction.new([{spend_blknum, 0, 0}], eth, [{bob.addr, 7}]) |>
  Transaction.sign(bob.priv, <<>>) |>
  Transaction.Signed.encode() |>
  Base.encode16()

# and send using curl as above. See the Watcher stop on an error

```
