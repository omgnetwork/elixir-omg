

```bash
# elsewhere run geth like:
geth --dev --rpc --rpcapi eth,personal

# following the advice in omisego_eth/config/dev.exs
mix run --no-start -e 'OmiseGO.Eth.DevHelpers.prepare_dev_env()'              #'

# wipe your omisego child chain db
rm -rf ~/.omisego

# start Elixir REPL
iex -S mix run --no-start
```

```elixir

### PREPARATIONS
{:ok, contract_address, _txhash, _authority} =

{:ok, started_apps} = Application.ensure_all_started(:omisego_db)

:ok = OmiseGO.DB.multi_update([{:put, :last_deposit_block_height, 0}])
:ok = OmiseGO.DB.multi_update([{:put, :child_top_block_number, 0}])

{:ok, started_apps} = Application.ensure_all_started(:omisego_api)

Code.load_file("apps/omisego_api/test/testlib/test_helper.ex")
alias OmiseGO.{API, Eth}
alias OmiseGO.API.Crypto
alias OmiseGO.API.State.Transaction
alias OmiseGO.API.TestHelper

alice = TestHelper.generate_entity()
bob = TestHelper.generate_entity()

{:ok, alice_enc} = TestHelper.import_unlock_fund(alice)


### START DEMO HERE

# sends a deposit transaction _to Ethereum_
{:ok, deposit_tx_hash} = Eth.deposit(10, 0, alice_enc, contract_address)

# need to wait until its mined
{:ok, _} = Eth.WaitFor.eth_receipt(deposit_tx_hash)

# we need to uncover the height at which the deposit went through on the root chain
# to do this, look in the logs inside the receipt printed just above
deposit_height_enc =
{deposit_height, ""} = Integer.parse(deposit_height_enc, 16)

# create and prepare transaction for singing
tx =
  Transaction.new([{deposit_height, 0, 0}], [{bob.addr, 7}, {alice.addr, 3}], 0) |>
  Transaction.sign(alice.priv, <<>>) |>
  Transaction.Signed.encode()

# submits a transaction to the child chain
# this only will work after the deposit has been "consumed" by the child chain, be patient (~15sec)
{:ok, child_tx_hash} = OmiseGO.API.submit(tx)

# FIXME: getting the block number where the tx was included and submited
OmiseGO.DB.utxos

# with that block, we can ask the root chain to give us the block hash
{:ok, {block_hash, _}} = OmiseGO.Eth.get_child_chain(___)

# with the block hash we can get the whole block
OmiseGO.API.get_block(block_hash)
```
