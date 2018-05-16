

```bash
# wipe your omisego child chain db
rm -rf ~/.omisego

# follow the developer's environment instructions to get a fresh child chain API running
```

```elixir

### PREPARATIONS
{:ok, contract_address, _txhash, _authority} =

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
{:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(10, 0, alice_enc, contract_address)

# need to wait until its mined
{:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)

# we need to uncover the height at which the deposit went through on the root chain
# to do this, look in the logs inside the receipt printed just above
deposit_height = Eth.DevHelpers.deposit_height_from_receipt(receipt)

# create and prepare transaction for singing
tx =
  Transaction.new([{deposit_height, 0, 0}], [{bob.addr, 7}, {alice.addr, 3}], 0) |>
  Transaction.sign(alice.priv, <<>>) |>
  Transaction.Signed.encode() |>
  Base.encode16()

# submits a transaction to the child chain
# this only will work after the deposit has been "consumed" by the child chain, be patient (~15sec)
{:ok, child_tx_hash, child_tx_block_number, child_tx_index} = OmiseGO.API.submit(tx)

# with that block, we can ask the root chain to give us the block hash
{:ok, {block_hash, _}} = Eth.get_child_chain(child_tx_block_number)

# with the block hash we can get the whole block
OmiseGO.API.get_block(Base.encode16(block_hash))
```
