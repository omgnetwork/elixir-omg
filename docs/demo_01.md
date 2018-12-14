# Submitting transactions and getting a submitted block from the child chain API

The following demo is a mix of commands executed in IEx (Elixir's) REPL (see README.md for instructions) and shell.

Run a developer's Child chain server and start IEx REPL with code and config loaded, as described in README.md instructions.

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

{:ok, alice_enc} = Eth.DevHelpers.import_unlock_fund(alice)

### START DEMO HERE

# sends a deposit transaction _to Ethereum_
{:ok, deposit_tx_hash} = Eth.RootChain.deposit(10, alice_enc)

# need to wait until its mined
{:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)

# we need to uncover the height at which the deposit went through on the root chain
# to do this, look in the logs inside the receipt printed just above
deposit_blknum = Eth.RootChain.deposit_blknum_from_receipt(receipt)

# create and prepare transaction for signing
tx =
  Transaction.new([{deposit_blknum, 0, 0}], [{bob.addr, eth, 7}, {alice.addr, eth, 3}]) |>
  Transaction.sign([alice.priv, <<>>]) |>
  Transaction.Signed.encode() |>
  Base.encode16()

```

```bash
# submits a transaction to the child chain
# this only will work after the deposit has been "consumed" by the child chain, be patient (~15sec)
# use the hex-encoded tx bytes and `transaction.submit` Http-RPC method described in README.md for child chain server

echo '{"transaction": "<rlp encoded plasma transaction in hex>"}' | http POST "localhost:9656/transaction.submit"
```

```elixir
# with that block number, we can ask the root chain to give us the block hash
child_tx_block_number =
{:ok, {block_hash, _}} = Eth.RootChain.get_child_chain(child_tx_block_number)
Base.encode16(block_hash)
```

```bash
# with the block hash we can get the whole block
echo '{"hash":"<block hash in hex>"}' | http POST "localhost:9656/block.get"

# if you were watching, you could have decoded and validated the transaction bytes in the block
```
