

```bash
# elsewhere run go-ethereum
geth --dev --rpc --rpcapi eth,personal

# following the advice in omisego_eth/convig/dev.exs
mix run --no-start -e 'OmiseGO.Eth.DevHelpers.prepare_dev_env()'              #'

iex -S mix run --no-start
```

```elixir
dir = Temp.mkdir!()

Application.put_env(:omisego_db, :leveldb_path, dir, persistent: true)
{:ok, started_apps} = Application.ensure_all_started(:omisego_db)

:ok = OmiseGO.DB.multi_update([{:put, :last_deposit_block_height, 0}])

{:ok, started_apps} = Application.ensure_all_started(:omisego_api)

alias OmiseGO.{API, Eth}
alias OmiseGO.API.Crypto
alias OmiseGO.API.State.Transaction

{:ok, alice_priv} = Crypto.generate_private_key; {:ok, alice_pub} = Crypto.generate_public_key alice_priv; {:ok, alice} = Crypto.generate_address alice_pub
{:ok, bob_priv} = Crypto.generate_private_key; {:ok, bob_pub} = Crypto.generate_public_key bob_priv; {:ok, bob} = Crypto.generate_address bob_pub

:ok = OmiseGO.API.State.deposit([%{owner: alice, amount: 10, blknum: 1}])

tx =
  %Transaction{
    blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
    newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
  } |> Transaction.sign(alice_priv, <<>>) |> Transaction.Signed.encode()

{:ok, child_tx_hash} = OmiseGO.API.submit(tx)

{:ok, _} = OmiseGO.Eth.DevHelpers.wait_for_current_child_block(2000, true)
{:ok, {block_hash, _}} = OmiseGO.Eth.get_child_chain(1000)

OmiseGO.API.get_block(block_hash)
```
