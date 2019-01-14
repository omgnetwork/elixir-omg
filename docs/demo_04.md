# In-flight exits

The following demo is a mix of commands executed in IEx (Elixir's) REPL (see README.md for instructions) and shell.

Run a developer's Child chain server, Watcher, and start IEx REPL with code and config loaded, as described in README.md instructions.

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
{:ok, deposit_tx_hash} =
  Transaction.new([], [{alice_enc, eth, 10}]) |>
  Transaction.encode() |>
  Eth.RootChain.deposit(10, alice_enc)

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

# submits a transaction to the child chain
# this only will work after the deposit has been "consumed" by the child chain, be patient (~15sec)
# use the hex-encoded tx bytes and `transaction.submit` Http-RPC method described in README.md for child chain server
%{"data" => %{"blknum" => child_tx_block_number, "tx_index" => tx_index}} =
  ~c(echo '{"transaction": "#{tx}"}' | http POST localhost:9656/transaction.submit) |>
  :os.cmd() |>
  Poison.decode!()

# create an in-flight transaction that uses tx's output as an input
in_flight_tx_bytes =
  Transaction.new([{child_tx_block_number, tx_index, 0}], [{alice.addr, eth, 7}]) |>
  Transaction.sign([bob.priv, <<>>]) |>
  Transaction.Signed.encode() |>
  Base.encode16()

# get in-flight exit data for tx

%{"data" => %{
    "in_flight_tx" => in_flight_tx,
    "in_flight_tx_sigs" => in_flight_tx_sigs,
    "input_txs" => input_txs,
    "input_txs_inclusion_proofs" => input_txs_inclusion_proofs
  }
} = ~c(echo '{"txbytes": "#{in_flight_tx_bytes}"}' | http POST localhost:7434/inflight_exit.get_data) |>
  :os.cmd() |>
  Poison.decode!()

{:ok, in_flight_tx} = Base.decode16(in_flight_tx, case: :mixed)
{:ok, in_flight_tx_sigs} = Base.decode16(in_flight_tx_sigs, case: :mixed)
{:ok, input_txs} = Base.decode16(input_txs, case: :mixed)
{:ok, input_txs_inclusion_proofs} = Base.decode16(input_txs_inclusion_proofs, case: :mixed)

# call root chain function that initiates in-flight exit
{:ok, txhash} =
  OMG.Eth.RootChain.in_flight_exit(
    in_flight_tx,
    input_txs,
    input_txs_inclusion_proofs,
    in_flight_tx_sigs,
    alice.addr
  )
{:ok, _} = Eth.WaitFor.eth_receipt(txhash)

# querying Ethereum for in-flight exits should return the initiated in-flight exit
{:ok, eth_height} = OMG.Eth.get_ethereum_height()
{:ok, [in_flight_exit]} = OMG.Eth.RootChain.get_in_flight_exits(0, eth_height)
```
