Code.load_file("apps/omisego_api/test/testlib/test_helper.ex")

alias OmiseGO.API.TestHelper
alias OmiseGO.API.State.Transaction

alice = "Alice"
bob = "Bob"

signed_tx =
  %Transaction{
    blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
    newowner1: bob, amount1: 7, newowner2: alice, amount2: 3, fee: 0,
  } |> TestHelper.signed

tx = %Transaction.Recovered{signed: signed_tx, spender1: alice}

{:error, :utxo_not_found} = OmiseGO.API.submit(tx)

:ok = OmiseGO.API.State.deposit("Alice", 10)

:ok = OmiseGO.API.submit(tx)

{:error, :utxo_not_found} = OmiseGO.API.submit(tx)

OmiseGO.API.State.form_block(2,3)
