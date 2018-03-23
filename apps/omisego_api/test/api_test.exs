defmodule OmiseGO.API.ApiTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.Core

  import OmiseGO.API.TestHelper

  @tag fixtures: [:alice, :bob]
  test "signed transaction is valid", %{alice: alice, bob: bob} do
    signed_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: alice.addr, amount1: 7, newowner2: bob.addr, amount2: 3, fee: 0,
      }
      |> signed(alice.priv, bob.priv)

    signed_tx
      |> Transaction.Signed.encode
      |> Core.recover_tx
      |> success?
      |> same?(%Transaction.Recovered{
        signed: signed_tx,
        spender1: alice.addr,
        spender2: bob.addr}
      )

  end

  test "encoded transaction is empty" do
    empty_tx = <<192>>

    to = empty_tx
      |> Core.recover_tx
      |> same?({:error, :malformed_transaction})

  end



end
