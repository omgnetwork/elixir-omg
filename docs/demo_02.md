# Watching a valid and invalid child chain

The following demo is a mix of commands executed in IEx (Elixir's) REPL (see README.md for instructions) and shell.

Run a developer's Child chain server, Watcher and start IEx REPL with code and config loaded, as described in README.md instructions.

**NOTE** you'll find it useful to run the child chain server with a IEx to recompile:
        iex -S mix run --config ...


```elixir

### PREPARATIONS

# we're going to be using the exthereum's client to geth's JSON RPC
{:ok, _} = Application.ensure_all_started(:ethereumex)

Code.load_file("apps/omisego_api/test/testlib/test_helper.ex")
alias OmiseGO.{API, Eth}
alias OmiseGO.API.Crypto
alias OmiseGO.API.State.Transaction
alias OmiseGO.API.TestHelper

alice = TestHelper.generate_entity()
bob = TestHelper.generate_entity()
eth = Crypto.zero_address()

{:ok, alice_enc} = Eth.DevHelpers.import_unlock_fund(alice)
{:ok, bob_enc} = Eth.DevHelpers.import_unlock_fund(bob)

# sends a deposit transaction _to Ethereum_
{:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(10, 0, alice_enc)
{:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(10, 0, alice_enc)

# need to wait until it's mined
{:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)

# we need to uncover the height at which the deposit went through on the root chain
# to do this, look in the logs inside the receipt printed just above
deposit_blknum = Eth.DevHelpers.deposit_blknum_from_receipt(receipt)

### START DEMO HERE

# we've got alice, bob prepared, also an honest child chain is running with a watcher connected

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

curl "localhost:9656" -d '{"params":{"transaction": ""}, "method": "submit", "jsonrpc": "2.0","id":0}'

# see the Watcher getting a 1-txs block
```

```elixir

# 2/ let's break the Child chain now and say that duplicates every transaction submitted!

# in order to do that you need to duplicate the `|> add_pending_tx(recovered_tx)` in API.State.Core module,
# around line 123

# now, with the code "broken" go to the `iex` repl and recompile the module

r(OmiseGO.API.State.Core)

# let's do a broken spend:

# grab the child block number from child chain server's response to the first tx
spend_blknum =

tx2 =
  Transaction.new([{spend_blknum, 0, 0}], eth, [{bob.addr, 7}]) |>
  Transaction.sign(bob.priv, <<>>) |>
  Transaction.Signed.encode() |>
  Base.encode16()

# and send using curl as above. See the Watcher puke out an error and stop (to be cleaned)

# 3/ Using the Watcher,

# re-prepare everything for the invalid exit demo until sending of tx1

tx1_hash =

"http GET 'localhost:4000/transactions/#{tx1_hash}'" |>
to_charlist() |>
:os.cmd() |>
Poison.decode!()

%{"utxos" => [%{"blknum" => exiting_utxo_blknum, "txindex" => 0, "oindex" => 0}]} =
  "http GET 'localhost:4000/account/utxo?address=#{bob.addr |> Base.encode16}'" |>
  to_charlist() |>
  :os.cmd() |>
  Poison.decode!()

# 4/ Exiting, challenging invalid exits



composed_exit =
  "http GET 'localhost:4000/account/utxo/compose_exit?blknum=#{exiting_utxo_blknum}&txindex=0&oindex=0'" |>
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
  Eth.start_exit(
    composed_exit.utxo_pos,
    Base.decode16!(composed_exit.tx_bytes),
    Base.decode16!(composed_exit.proof),
    Base.decode16!(composed_exit.sigs),
    1,
    bob_enc
  )
Eth.WaitFor.eth_receipt(txhash)

challenge =
  "http GET 'localhost:4000/challenges?blknum=#{exiting_utxo_blknum}&txindex=0&oindex=0'" |>
  to_charlist() |>
  :os.cmd() |>
  Poison.decode!()

{:ok, txhash} =
  OmiseGO.Eth.DevHelpers.challenge_exit(
    challenge["cutxopos"],
    challenge["eutxoindex"],
    Base.decode16!(challenge["txbytes"]),
    Base.decode16!(challenge["proof"]),
    Base.decode16!(challenge["sigs"]),
    1,
    alice_enc
  )

{:ok, _} = Eth.WaitFor.eth_receipt(txhash)


```
