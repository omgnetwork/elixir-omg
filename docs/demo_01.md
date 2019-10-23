# Submitting transactions and getting a submitted block from the child chain API

The following demo is a mix of commands executed in IEx (Elixir's) REPL (see README.md for instructions) and shell.

Run a developer's Child chain server and start IEx REPL with code and config loaded, as described in README.md instructions.

```elixir

### PREPARATIONS

# we're going to be using the exthereum's client to geth's JSON RPC
{:ok, _} = Application.ensure_all_started(:ethereumex)

alias OMG.Eth
alias OMG.DevCrypto
alias OMG.State.Transaction
alias OMG.TestHelper
alias Support.Integration.DepositHelper

alice = TestHelper.generate_entity()
bob = TestHelper.generate_entity()
eth = Eth.RootChain.eth_pseudo_address()

{:ok, _} = Support.DevHelper.import_unlock_fund(alice)

child_chain_url = "localhost:9656"

### START DEMO HERE

# sends a deposit transaction _to Ethereum_
# we need to uncover the height at which the deposit went through on the root chain
deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, 10)

# create and prepare transaction for signing
tx =
  Transaction.Payment.new([{deposit_blknum, 0, 0}], [{bob.addr, eth, 7}, {alice.addr, eth, 3}]) |>
  DevCrypto.sign([alice.priv]) |>
  Transaction.Signed.encode() |>
  OMG.Utils.HttpRPC.Encoding.to_hex()

# submits a transaction to the child chain
# this only will work after the deposit has been "consumed" by the child chain, be patient (~15sec)
# use the hex-encoded tx bytes and `transaction.submit` Http-RPC method described in README.md for child chain server
%{"data" => %{"blknum" => child_tx_block_number}} =
  ~c(echo '{"transaction": "#{tx}"}' | http POST #{child_chain_url}/transaction.submit) |>
  :os.cmd() |>
  Jason.decode!()

# with that block number, we can ask the root chain to give us the block hash
{:ok, {block_hash, _}} = Eth.RootChain.get_child_chain(child_tx_block_number)
block_hash_enc = OMG.Utils.HttpRPC.Encoding.to_hex(block_hash)

# with the block hash we can get the whole block
~c(echo '{"hash":"#{block_hash_enc}"}' | http POST #{child_chain_url}/block.get) |>
:os.cmd() |>
Jason.decode!()

# if you were watching, you could have decoded and validated the transaction bytes in the block
```
