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

    event_1 = {"address:" <> encoded_alice_address, "address_received", %Event.AddressReceived{tx: recovered_tx}}

    event_2 = {"address:" <> encoded_bob_address, "address_received", %Event.AddressReceived{tx: recovered_tx}}

    assert [event_1, event_2] == Eventer.Core.prepare_events([%{tx: recovered_tx}])
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

    event_owner_1 = {"address:" <> encoded_alice_address, "address_received", %Event.AddressReceived{tx: recovered_tx}}

    assert [event_owner_1] == Eventer.Core.prepare_events([%{tx: recovered_tx}])
  end

  test "notify function generates one block_withholdings event" do

    block_withholding_event = %Event.BlockWithHoldings{blknums: [1, 2]}
    event = {"byzantine", "block_withholdings", block_withholding_event}

    assert event == Eventer.Core.prepare_event(block_withholding_event)
  end

end
