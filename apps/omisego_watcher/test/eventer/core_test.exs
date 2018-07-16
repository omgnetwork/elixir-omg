defmodule OmiseGOWatcher.Eventer.CoreTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OmiseGO.API.Fixtures

  alias OmiseGO.API
  alias OmiseGOWatcher.Eventer
  alias OmiseGOWatcher.Eventer.Event

  @tag fixtures: [:alice, :bob]
  test "notify function generates 2 proper address_received events", %{alice: alice, bob: bob} do
    recovered_tx =
      API.TestHelper.create_recovered([{1, 0, 0, alice}, {2, 0, 0, bob}], API.Crypto.zero_address(), [
        {alice, 100},
        {bob, 5}
      ])

    encoded_alice_address = API.TestHelper.encode_address(alice.addr)
    encoded_bob_address = API.TestHelper.encode_address(bob.addr)

    {topic_1, event_name_1, event_1} =
      {"address:" <> encoded_alice_address, "address_received", %Event.AddressReceived{tx: recovered_tx}}

    {topic_2, event_name_2, event_2} =
      {"address:" <> encoded_bob_address, "address_received", %Event.AddressReceived{tx: recovered_tx}}

    assert [{topic_1, event_name_1, event_1}, {topic_2, event_name_2, event_2}] ==
             Eventer.Core.notify([%{tx: recovered_tx}])
  end

  @tag fixtures: [:alice, :bob]
  test "notify function generates 1 proper address_received events", %{alice: alice} do
    recovered_tx = API.TestHelper.create_recovered([{1, 0, 0, alice}], API.Crypto.zero_address(), [{alice, 100}])

    encoded_alice_address = API.TestHelper.encode_address(alice.addr)

    {topic, event_name, event} =
      {"address:" <> encoded_alice_address, "address_received", %Event.AddressReceived{tx: recovered_tx}}

    assert [{topic, event_name, event}] == Eventer.Core.notify([%{tx: recovered_tx}])
  end
end
