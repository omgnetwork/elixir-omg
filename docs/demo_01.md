# Submitting transactions and getting a submitted block from the child chain API

The following demo is a mix of commands executed in IEx (Elixir's) REPL (see README.md for instructions) and shell.
**NOTE**: start IEx REPL with code and config loaded, as described in README.md instructions.

```elixir

### PREPARATIONS

# we're going to be using the exthereum's client to geth's JSON RPC
{:ok, _} = Application.ensure_all_started(:ethereumex)

# (paste output from `prepare_env!` to setup the REPL environment)
contract_address = Application.get_env(:omisego_eth, :contract_addr)

Code.load_file("apps/omisego_api/test/testlib/test_helper.ex")
alias OmiseGO.{API, Eth}
alias OmiseGO.API.Crypto
alias OmiseGO.API.State.Transaction
alias OmiseGO.API.TestHelper

alice = TestHelper.generate_entity()
bob = TestHelper.generate_entity()

{:ok, alice_enc} = Eth.DevHelpers.import_unlock_fund(alice)


### START DEMO HERE

# sends a deposit transaction _to Ethereum_
{:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(10, 0, alice_enc)

# need to wait until its mined
{:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)

# we need to uncover the height at which the deposit went through on the root chain
# to do this, look in the logs inside the receipt printed just above
deposit_blknum = Eth.DevHelpers.deposit_blknum_from_receipt(receipt)

eth = Crypto.zero_address()

# create and prepare transaction for singing
tx =
  Transaction.new([{deposit_blknum, 0, 0}], eth, [{bob.addr, 7}, {alice.addr, 3}]) |>
  Transaction.sign(alice.priv, <<>>) |>
  Transaction.Signed.encode() |>
  Base.encode16()

```

```bash
# submits a transaction to the child chain
# this only will work after the deposit has been "consumed" by the child chain, be patient (~15sec)
# use the hex-encoded tx bytes and `submit` JSONRPC method descibed in README.md for child chain server

curl "localhost:9656" -d '{"params":{"transaction": ""}, "method": "submit", "jsonrpc": "2.0","id":0}'
```

```elixir
# with that block number, we can ask the root chain to give us the block hash
child_tx_block_number =
{:ok, {block_hash, _}} = Eth.get_child_chain(child_tx_block_number)
Base.encode16(block_hash)
```

```bash
# with the block hash we can get the whole block
curl "localhost:9656" -d '{"params":{"hash":""}, "method":"get_block", "jsonrpc":"2.0", "id":0}'

# if you were watching, you could have decoded and validated the transaction bytes in the block
```
