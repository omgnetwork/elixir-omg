defmodule OmiseGOWatcher.Eventer.CoreTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true

  use OmiseGO.API.Fixtures

  alias OmiseGO.API
  alias OmiseGO.API.State.Transaction
  alias OmiseGOWatcher.Eventer
  alias OmiseGOWatcher.Eventer.Notification.Received

  # TODO: implement all tests and write moduledoc
  test "notifications for finalied block event are created" do
  end

  @tag fixtures: [:alice]
  test "receiver is notified about deposit", %{alice: %{priv: alice_priv, addr: alice_addr}} do
    # TODO: first draft

    raw_tx = %Transaction{
      blknum1: 1,
      txindex1: 0,
      oindex1: 0,
      blknum2: 0,
      txindex2: 0,
      oindex2: 0,
      cur12: OmiseGO.API.Crypto.zero_address(),
      newowner1: alice_addr,
      amount1: 100,
      newowner2: OmiseGO.API.Crypto.zero_address(),
      amount2: 0
    }

    # TODO: We're ignoring second spedner. Rethink this
    encoded_singed_tx =
      raw_tx
      |> Transaction.sign(alice_priv, <<>>)
      |> Transaction.Signed.encode()

    {:ok, recovered_tx} = API.Core.recover_tx(encoded_singed_tx)

    assert [_, {%Received{tx: ^recovered_tx}, "transactions/received/" <> ^alice_addr}] =
             Eventer.Core.notify([%{tx: recovered_tx}])
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
