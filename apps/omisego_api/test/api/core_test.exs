defmodule OmiseGO.API.Api.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.Core

  @tag fixtures: [:alice, :bob]
  test "signed transaction is valid", %{alice: %{priv: alice_priv, addr: alice_addr},
                                        bob: %{priv: bob_priv, addr: bob_addr}} do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 2, oindex1: 1, blknum2: 2, txindex2: 3, oindex2: 1,
        newowner1: alice_addr, amount1: 7, newowner2: bob_addr, amount2: 3, fee: 1,
      }

    signed_tx = Transaction.signed(raw_tx, alice_priv, bob_priv)

    signed_tx_hash = Transaction.Signed.hash(signed_tx)

    encoded_signed_tx = Transaction.Signed.encode(signed_tx)

    assert {
      :ok,
      %Transaction.Recovered{
        raw_tx: ^raw_tx,
        signed_tx_hash: ^signed_tx_hash,
        spender1: ^alice_addr,
        spender2: ^bob_addr,
      }} = Core.recover_tx(encoded_signed_tx)

    raw_tx = %{raw_tx | txindex2: 0}

    {:ok, recovered} = Core.recover_tx(encoded_signed_tx)

    assert raw_tx != recovered.raw_tx.txindex2

  end

  test "encoded transaction is empty" do
    empty_tx = <<192>>

    assert {
      :error,
      :malformed_transaction
    } = Core.recover_tx(empty_tx)

  end

end
