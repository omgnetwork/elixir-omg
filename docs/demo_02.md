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

# sends a deposit transaction _to Ethereum_
{:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(10, 0, alice_enc)

# need to wait until its mined
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

```
