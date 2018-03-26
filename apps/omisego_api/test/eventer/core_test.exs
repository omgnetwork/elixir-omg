defmodule OmiseGO.API.Eventer.CoreTest do

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.Eventer.Core
  alias OmiseGO.API.Notification.Received
  alias OmiseGO.API.State.Transaction

  #TODO: implement all tests
  test "notifications for finalied block event are created" do
  end

  @tag fixtures: [:alice]
  test "receiver is notified about deposit", %{alice: %{priv: alice_priv, addr: alice_addr}} do
    raw_tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: alice_addr, amount1: 100, newowner2: Transaction.zero_address, amount2: 0, fee: 0
      }

    signed_tx_hash =
      raw_tx
      |> Transaction.signed(alice_priv, <<>>)
      |> Transaction.Signed.hash

    recovered_tx = %Transaction.Recovered{raw_tx: raw_tx, signed_tx_hash: signed_tx_hash}

    [{%Received{tx: ^recovered_tx}, "transactions/received/" <> ^alice_addr}] =
      Core.notify([%{tx: recovered_tx}])
  end

  test "spenders are notified about transactions" do
  end

  test "spender is notified only once when both transaction input are hers" do
  end

  test "receivers are notified about transactions" do
  end

  test "transaction receiver is notified once when both transaction outputs are hers" do
  end
end
