# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.Eventer.CoreTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.Fixtures

  alias OMG.Crypto
  alias OMG.Utxo
  alias OMG.Watcher.Event
  alias OMG.Watcher.Eventer
  alias OMG.Watcher.TestHelper

  require Utxo

  @zero_address OMG.Eth.zero_address()

  @tag fixtures: [:alice, :bob]
  test "notify function generates 2 proper address_received events", %{alice: alice, bob: bob} do
    recovered_tx =
      OMG.TestHelper.create_recovered([{1, 0, 0, alice}, {2, 0, 0, bob}], @zero_address, [
        {alice, 100},
        {bob, 5}
      ])

    {:ok, encoded_alice_address} = Crypto.encode_address(alice.addr)
    {:ok, encoded_bob_address} = Crypto.encode_address(bob.addr)
    topic_alice = TestHelper.create_topic("transfer", encoded_alice_address)
    topic_bob = TestHelper.create_topic("transfer", encoded_bob_address)

    event_1 = {topic_alice, "address_received", %Event.AddressReceived{tx: recovered_tx}}

    event_2 = {topic_bob, "address_received", %Event.AddressReceived{tx: recovered_tx}}

    event_3 = {topic_alice, "address_spent", %Event.AddressSpent{tx: recovered_tx}}

    event_4 = {topic_bob, "address_spent", %Event.AddressSpent{tx: recovered_tx}}

    assert [event_1, event_2, event_3, event_4] == Eventer.Core.pair_events_with_topics([%{tx: recovered_tx}])
  end

  @tag fixtures: [:alice, :bob]
  test "prepare_events function generates 1 proper address_received events", %{alice: alice} do
    recovered_tx = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @zero_address, [{alice, 100}])

    {:ok, encoded_alice_address} = Crypto.encode_address(alice.addr)
    topic = TestHelper.create_topic("transfer", encoded_alice_address)

    event_1 = {topic, "address_received", %Event.AddressReceived{tx: recovered_tx}}

    event_2 = {topic, "address_spent", %Event.AddressSpent{tx: recovered_tx}}

    assert [event_1, event_2] == Eventer.Core.pair_events_with_topics([%{tx: recovered_tx}])
  end

  @tag fixtures: [:alice]
  test "generates proper exit finalized event", %{alice: alice} do
    event_trigger = %{
      exit_finalized: %{owner: alice.addr, currency: @zero_address, amount: 7, utxo_pos: Utxo.position(1, 0, 0)}
    }

    {:ok, encoded_alice_address} = Crypto.encode_address(alice.addr)

    topic = TestHelper.create_topic("exit", encoded_alice_address)

    event =
      {topic, "exit_finalized",
       %Event.ExitFinalized{amount: 7, currency: @zero_address, child_blknum: 1, child_txindex: 0, child_oindex: 0}}

    assert [event] == Eventer.Core.pair_events_with_topics([event_trigger])
  end
end
