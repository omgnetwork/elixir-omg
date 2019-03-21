# Submitting transactions and getting a submitted block from the child chain API using ERC20 Deposits

This demo is similar to demo_01, with the difference that is using ERC20 deposits, instead of ETH. A new ERC20 is created on each run, leveraging the MintableToken contract.

Run a developer's Child chain server and start IEx REPL with code and config loaded, as described in README.md instructions. Commands are executed inside the REPL.

```elixir

### PREPARATIONS

# we're going to be using the exthereum's client to geth's JSON RPC
{:ok, _} = Application.ensure_all_started(:ethereumex)

alias OMG.{API, Eth}
alias OMG.API.Crypto
alias OMG.API.DevCrypto
alias OMG.API.State.Transaction
alias OMG.API.TestHelper
alias OMG.API.Integration.DepositHelper
alias OMG.Eth.Encoding

alice = TestHelper.generate_entity()
bob = TestHelper.generate_entity()
eth = Eth.RootChain.eth_pseudo_address()

{:ok, _} = Eth.DevHelpers.import_unlock_fund(alice)

child_chain_url = "localhost:9656"

### START DEMO HERE

# Create new ERC20 token using MintableToken.sol from plasma_contracts. Alice deploys the contract, she is the owner.
{:ok, _, token_addr} = Eth.Deployer.create_new(OMG.Eth.Token, "./", alice.addr)

# Add the created token to the RootChain contract.
{:ok, _} = Eth.RootChain.add_token(token_addr) |> Eth.DevHelpers.transact_sync!()

# Mint 20 new tokens. Alice can do it, because she is the owner.
Eth.Token.mint(alice.addr, 20, token_addr) |> Eth.DevHelpers.transact_sync!()

# Retrieve the address of the RootChain contract to be used below.
contract_addr = Encoding.from_hex(Application.fetch_env!(:omg_eth, :contract_addr))

# Approve 20 tokens as being able to be deposited to RootChain contract.
Eth.Token.approve(alice.addr, contract_addr, 20, token_addr) |> Eth.DevHelpers.transact_sync!()

# Deposit 20 tokens. Find the block number of the deposit transaction, by looking in the logs inside the receipt.
deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, 20, token_addr)

# Before proceeding, you need to manually add an entry { "token": <token address here>, "flat_fee": 0 } to fee_specs.json file, located in the root folder, for allowing transactions with the specific token. Use the output of the following command to get the token address. 
Encoding.to_hex(token_addr)

# create and prepare transaction for signing
tx =
  Transaction.new([{deposit_blknum, 0, 0}], [{bob.addr, token_addr, 9}, {alice.addr, token_addr, 11}]) |>
  DevCrypto.sign([alice.priv, <<>>]) |>
  Transaction.Signed.encode() |>
  OMG.RPC.Web.Encoding.to_hex()

# submits a transaction to the child chain
# this only will work after the deposit has been "consumed" by the child chain, be patient (~15sec)
# use the hex-encoded tx bytes and `transaction.submit` Http-RPC method described in README.md for child chain server
%{"data" => %{"blknum" => child_tx_block_number}} =
  ~c(echo '{"transaction": "#{tx}"}' | http POST #{child_chain_url}/transaction.submit) |>
  :os.cmd() |>
  Poison.decode!()

# with that block number, we can ask the root chain to give us the block hash
{:ok, {block_hash, _}} = Eth.RootChain.get_child_chain(child_tx_block_number)
block_hash_enc = OMG.RPC.Web.Encoding.to_hex(block_hash)

# with the block hash we can get the whole block
~c(echo '{"hash":"#{block_hash_enc}"}' | http POST #{child_chain_url}/block.get) |>
:os.cmd() |>
Poison.decode!()

# if you were watching, you could have decoded and validated the transaction bytes in the block
```
