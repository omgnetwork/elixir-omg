defmodule OmiseGOWatcher.Eventer.CoreTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OmiseGO.API.Fixtures

  alias OmiseGO.API
  alias OmiseGO.API.State.Transaction
  alias OmiseGOWatcher.Eventer
  alias OmiseGOWatcher.Eventer.Event

  @tag fixtures: [:alice, :bob]
  test "notify function generates 2 proper address_received events", %{alice: alice, bob: bob} do
    raw_tx = %Transaction{
      blknum1: 1,
      txindex1: 0,
      oindex1: 0,
      blknum2: 1,
      txindex2: 0,
      oindex2: 0,
      cur12: Transaction.zero_address(),
      newowner1: alice.addr,
      amount1: 100,
      newowner2: bob.addr,
      amount2: 0
    }

    encoded_singed_tx =
      raw_tx
      |> Transaction.sign(alice.priv, bob.priv)
      |> Transaction.Signed.encode()

    {:ok, recovered_tx} = API.Core.recover_tx(encoded_singed_tx)

    encoded_alice_address = "0x" <> Base.encode16(alice.addr, case: :lower)
    encoded_bob_address = "0x" <> Base.encode16(bob.addr, case: :lower)

    event_received_1 = {"address:" <> encoded_alice_address, "address_received", %Event.AddressReceived{tx: recovered_tx}}
    event_received_2 = {"address:" <> encoded_bob_address, "address_received", %Event.AddressReceived{tx: recovered_tx}}
    event_spender_1 = {"address:" <> encoded_alice_address, "address_spent", %Event.AddressSpent{tx: recovered_tx}}
    event_spender_2 = {"address:" <> encoded_bob_address, "address_spent", %Event.AddressSpent{tx: recovered_tx}}

    assert [event_received_1, event_received_2, event_spender_1, event_spender_2] == Eventer.Core.notify([%{tx: recovered_tx}])
  end

  @tag fixtures: [:alice, :bob]
  test "notify function generates 1 proper address_received events", %{alice: alice} do
    raw_tx = %Transaction{
      blknum1: 1,
      txindex1: 0,
      oindex1: 0,
      blknum2: 1,
      txindex2: 0,
      oindex2: 0,
      cur12: Transaction.zero_address(),
      newowner1: alice.addr,
      amount1: 100,
      newowner2: Transaction.zero_address(),
      amount2: 0
    }

    encoded_singed_tx =
      raw_tx
      |> Transaction.sign(alice.priv, alice.priv)
      |> Transaction.Signed.encode()

    {:ok, recovered_tx} = API.Core.recover_tx(encoded_singed_tx)

    encoded_alice_address = "0x" <> Base.encode16(alice.addr, case: :lower)

    event_received_1 = {"address:" <> encoded_alice_address, "address_received", %Event.AddressReceived{tx: recovered_tx}}
    event_spender_1 = {"address:" <> encoded_alice_address, "address_spent", %Event.AddressSpent{tx: recovered_tx}}

    assert [event_received_1, event_spender_1] == Eventer.Core.notify([%{tx: recovered_tx}])
  end
end
