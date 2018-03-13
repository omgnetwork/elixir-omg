defmodule OmiseGO.API.Eventer.CoreTest do

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.Eventer.Core
  alias OmiseGO.API.Notification.Received
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Transaction.Recovered
  alias OmiseGO.API.TestHelper

  #TODO: implement all tests
  test "notifications for finalied block event are created" do
  end

  test "receiver is notified about deposit" do
    depositor = "depositor"
    signed_deposit =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: depositor, amount1: 100, newowner2: Transaction.zero_address, amount2: 0, fee: 0
      }
      |> TestHelper.signed

    recovered_tx = %Recovered{signed: signed_deposit}
    [{%Received{tx: ^signed_deposit}, "transactions/received/" <> ^depositor}] =
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
