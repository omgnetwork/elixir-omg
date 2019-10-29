# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.Performance.ByzantineEventsTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.ChildChain.Integration.Fixtures
  use OMG.Watcher.Fixtures

  alias OMG.Performance
  alias OMG.Performance.ByzantineEvents
  alias OMG.Performance.ByzantineEvents.Generators

  @moduletag :integration
  @moduletag timeout: 180_000

  @tag fixtures: [:contract, :child_chain, :omg_watcher]
  test "can provide timing of response when asking for exit data", %{contract: %{contract_addr: contract_addr}} do
    exiting_users = 3
    spenders = Generators.generate_users(2)
    ntx_to_send = 10 * length(spenders)
    exits_per_user = length(spenders) * ntx_to_send
    total_exits = exiting_users * exits_per_user

    %{
      opts: %{
        ntx_to_send: ^ntx_to_send,
        exits_per_user: ^exits_per_user
      },
      statistics: statistics
    } = Performance.start_standard_exit_perftest(spenders, exiting_users, contract_addr)

    correct_exits = statistics |> Enum.map(&Map.get(&1, :corrects_count)) |> Enum.sum()
    error_exits = statistics |> Enum.map(&Map.get(&1, :errors_count)) |> Enum.sum()

    assert total_exits == correct_exits + error_exits
    assert error_exits == 0
  end

  @tag fixtures: [:contract, :child_chain, :omg_watcher]
  test "can provide timing of status.get under many valid SEs", %{contract: %{contract_addr: contract_addr}} do
    spenders = Generators.generate_users(2)
    :ok = Performance.start_extended_perftest(100, spenders, contract_addr, %{randomized: true})
    :ok = ByzantineEvents.watcher_synchronize()
    alice = Enum.at(spenders, 0)

    # FIXME: maybe let's do the &1.utxo_pos for get_exitable_utxos right away (and also allow to Enum.take there maybe?)
    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      ByzantineEvents.get_exitable_utxos(alice.addr)
      |> Enum.map(& &1.utxo_pos)
      |> Enum.take(20)
      |> ByzantineEvents.start_many_exits(alice.addr)

    OMG.Watcher.Integration.TestHelper.wait_for_exit_processing(last_exit_height)
    # assert that we can call this testing function reliably and that there are no invalid exits
    assert [] = ByzantineEvents.get_byzantine_events("invalid_exit")
  end

  @tag fixtures: [:contract, :child_chain, :omg_watcher]
  test "can provide timing of status.get under many valid/invalid SEs", %{contract: %{contract_addr: contract_addr}} do
    spenders = Generators.generate_users(2)
    :ok = Performance.start_extended_perftest(100, spenders, contract_addr, %{randomized: true})
    :ok = ByzantineEvents.watcher_synchronize()
    alice = Enum.at(spenders, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      ByzantineEvents.Generators.stream_utxo_positions(nil, owned_by: alice.addr)
      |> Enum.take(20)
      |> ByzantineEvents.start_many_exits(alice.addr)

    OMG.Watcher.Integration.TestHelper.wait_for_exit_processing(last_exit_height)
    # assert that we can call this testing function reliably and that there are some invalid exits there in fact
    assert Enum.count(ByzantineEvents.get_byzantine_events("invalid_exit")) > 10
  end

  @tag fixtures: [:contract, :child_chain, :omg_watcher]
  test "can provide timing of challenging", %{contract: %{contract_addr: contract_addr}} do
    spenders = Generators.generate_users(2)
    :ok = Performance.start_extended_perftest(100, spenders, contract_addr, %{randomized: true})
    :ok = ByzantineEvents.watcher_synchronize()
    alice = Enum.at(spenders, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      ByzantineEvents.Generators.stream_utxo_positions(nil, owned_by: alice.addr)
      |> Enum.take(20)
      |> ByzantineEvents.start_many_exits(alice.addr)

    OMG.Watcher.Integration.TestHelper.wait_for_exit_processing(last_exit_height)

    utxos_to_challenge = ByzantineEvents.get_byzantine_events("invalid_exit") |> Enum.map(& &1["details"]["utxo_pos"])

    # assert that we can call this testing function reliably
    # FIXME: expand the assertion somehow? introduce `:ok` responses?
    assert [_ | _] = ByzantineEvents.get_challenge_data(utxos_to_challenge)
  end

  @tag fixtures: [:contract, :child_chain, :omg_watcher]
  test "can provide timing of status.get under many challenged SEs", %{contract: %{contract_addr: contract_addr}} do
    spenders = Generators.generate_users(2)
    :ok = Performance.start_extended_perftest(100, spenders, contract_addr, %{randomized: true})
    :ok = ByzantineEvents.watcher_synchronize()
    alice = Enum.at(spenders, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      ByzantineEvents.Generators.stream_utxo_positions(nil, owned_by: alice.addr)
      |> Enum.take(20)
      |> ByzantineEvents.start_many_exits(alice.addr)

    OMG.Watcher.Integration.TestHelper.wait_for_exit_processing(last_exit_height)

    # assert we can process the many challenges and get status then
    {:ok, %{"status" => "0x1", "blockNumber" => last_challenge_height}} =
      ByzantineEvents.get_byzantine_events("invalid_exit")
      |> Enum.map(& &1["details"]["utxo_pos"])
      |> ByzantineEvents.get_challenge_data()
      |> ByzantineEvents.challenge_many_exits(alice.addr)

    OMG.Watcher.Integration.TestHelper.wait_for_exit_processing(last_challenge_height)
    assert [] = ByzantineEvents.get_byzantine_events("invalid_exit")
  end
end
