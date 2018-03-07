defmodule OmiseGO.API.Eventer.CoreTest do

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.Eventer.Core
  alias OmiseGO.API.Notification.Received
  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Transaction.Recovered


  #TODO: implement all tests
  test "notifications for finalied block event are created" do
  end

  test "receiver is notified about deposit" do
    depositor = "depositor"
    transaction = Transaction.new_deposit(depositor, 100)
    recovered_tx = %Recovered{raw_tx: transaction}
    [[notification: %Received{tx: ^transaction}, topic: "transactions/received/" <> ^depositor]] =
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
