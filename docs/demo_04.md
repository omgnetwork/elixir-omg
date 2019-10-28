# In-flight exits

The following demo is a mix of commands executed in IEx (Elixir's) REPL (see README.md for instructions) and shell.

Run a developer's Child chain server, Watcher, and start IEx REPL with code and config loaded, as described in README.md instructions.

```elixir

### PREPARATIONS

# we're going to be using the exthereum's client to geth's JSON RPC
{:ok, _} = Application.ensure_all_started(:ethereumex)

alias OMG.Eth
alias OMG.Crypto
alias OMG.DevCrypto
alias Support.Integration.DepositHelper
alias Support.WaitFor
alias Support.RootChainHelper
alias OMG.State.Transaction
alias OMG.TestHelper
alias OMG.Eth.Encoding

alice = TestHelper.generate_entity()
bob = TestHelper.generate_entity()
eth = Eth.RootChain.eth_pseudo_address()

{:ok, alice_enc} = Support.DevHelper.import_unlock_fund(alice)

child_chain_url = "localhost:9656"
watcher_url = "localhost:7434"

### START DEMO HERE

# sends a deposit transaction _to Ethereum_
# we need to uncover the height at which the deposit went through on the root chain
# to do this, look in the logs inside the receipt printed just above
deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, 10)

# create and prepare transaction for signing
tx =
  Transaction.Payment.new([{deposit_blknum, 0, 0}], [{bob.addr, eth, 7}, {alice.addr, eth, 3}]) |>
  DevCrypto.sign([alice.priv]) |>
  Transaction.Signed.encode() |>
  Encoding.to_hex()

# submits a transaction to the child chain
# this only will work after the deposit has been "consumed" by the child chain, be patient (~15sec)
# use the hex-encoded tx bytes and `transaction.submit` Http-RPC method described in README.md for child chain server
%{"data" => %{"blknum" => child_tx_block_number, "txindex" => tx_index}} =
  ~c(echo '{"transaction": "#{tx}"}' | http POST #{child_chain_url}/transaction.submit) |>
  :os.cmd() |>
  Jason.decode!()

# create an in-flight transaction that uses tx's output as an input
in_flight_tx_bytes =
  Transaction.Payment.new([{child_tx_block_number, tx_index, 0}], [{alice.addr, eth, 7}]) |>
  DevCrypto.sign([bob.priv]) |>
  Transaction.Signed.encode() |>
  Encoding.to_hex()

# get in-flight exit data for tx

%{"data" => get_in_flight_exit_response} =
  ~c(echo '{"txbytes": "#{in_flight_tx_bytes}"}' | http POST #{watcher_url}/in_flight_exit.get_data) |>
  :os.cmd() |>
  Jason.decode!()

# call root chain function that initiates in-flight exit
{:ok, txhash} =
  RootChainHelper.in_flight_exit(
    get_in_flight_exit_response["in_flight_tx"] |> Encoding.from_hex(),
    get_in_flight_exit_response["input_txs"] |> Encoding.from_hex(),
    get_in_flight_exit_response["input_txs_inclusion_proofs"] |> Encoding.from_hex(),
    get_in_flight_exit_response["in_flight_tx_sigs"] |> Encoding.from_hex(),
    alice.addr
  )
{:ok, _} = WaitFor.eth_receipt(txhash)

# querying Ethereum for in-flight exits should return the initiated in-flight exit
{:ok, eth_height} = OMG.Eth.get_ethereum_height()
{:ok, [in_flight_exit]} = OMG.Eth.RootChain.get_in_flight_exit_starts(0, eth_height)
```
