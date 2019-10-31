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

  # FIXME: try to turn into setup (no fixture)
  deffixture perf_test(contract) do
    %{contract_addr: contract_addr} = contract
    :ok = Performance.init(%{contract_addr: contract_addr})
    {:ok, destdir} = Briefly.create(directory: true, prefix: "temp_results")
    {:ok, %{destdir: destdir}}
  end

  @tag fixtures: [:perf_test, :child_chain, :omg_watcher]
  test "can provide timing of response when asking for exit data", %{perf_test: {:ok, %{destdir: destdir}}} do
    spenders = Generators.generate_users(2)
    :ok = Performance.start_extended_perftest(100, spenders, %{randomized: false, destdir: destdir})
    :ok = ByzantineEvents.watcher_synchronize()
    alice = Enum.at(spenders, 0)

    ByzantineEvents.get_exitable_utxos(alice.addr)
    |> Enum.map(& &1.utxo_pos)
    |> Enum.take(20)
    |> ByzantineEvents.get_many_standard_exits()
  end

  @tag fixtures: [:perf_test, :child_chain, :omg_watcher]
  test "can provide timing of status.get under many valid SEs", %{perf_test: {:ok, %{destdir: destdir}}} do
    spenders = Generators.generate_users(2)
    :ok = Performance.start_extended_perftest(100, spenders, %{randomized: false, destdir: destdir})
    :ok = ByzantineEvents.watcher_synchronize()
    alice = Enum.at(spenders, 0)

    # FIXME: maybe let's do the &1.utxo_pos for get_exitable_utxos right away (and also allow to Enum.take there maybe?)
    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      ByzantineEvents.get_exitable_utxos(alice.addr)
      |> Enum.map(& &1.utxo_pos)
      |> Enum.take(20)
      |> ByzantineEvents.start_many_exits(alice.addr)

    :ok = ByzantineEvents.watcher_synchronize(last_exit_height)
    # assert that we can call this testing function reliably and that there are no invalid exits
    assert [] = ByzantineEvents.get_byzantine_events("invalid_exit")
  end

  @tag fixtures: [:perf_test, :child_chain, :omg_watcher]
  test "can provide timing of status.get under many valid/invalid SEs", %{perf_test: {:ok, %{destdir: destdir}}} do
    spenders = Generators.generate_users(2)
    :ok = Performance.start_extended_perftest(100, spenders, %{randomized: true, destdir: destdir})
    :ok = ByzantineEvents.watcher_synchronize()
    alice = Enum.at(spenders, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      ByzantineEvents.Generators.stream_utxo_positions(nil, owned_by: alice.addr)
      |> Enum.take(20)
      |> ByzantineEvents.start_many_exits(alice.addr)

    :ok = ByzantineEvents.watcher_synchronize(last_exit_height)
    # assert that we can call this testing function reliably and that there are some invalid exits there in fact
    assert Enum.count(ByzantineEvents.get_byzantine_events("invalid_exit")) > 10
  end

  @tag fixtures: [:perf_test, :child_chain, :omg_watcher]
  test "can provide timing of challenging", %{perf_test: {:ok, %{destdir: destdir}}} do
    spenders = Generators.generate_users(2)
    :ok = Performance.start_extended_perftest(100, spenders, %{randomized: true, destdir: destdir})
    :ok = ByzantineEvents.watcher_synchronize()
    alice = Enum.at(spenders, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      ByzantineEvents.Generators.stream_utxo_positions(nil, owned_by: alice.addr)
      |> Enum.take(20)
      |> ByzantineEvents.start_many_exits(alice.addr)

    :ok = ByzantineEvents.watcher_synchronize(last_exit_height)

    utxos_to_challenge = ByzantineEvents.get_byzantine_events("invalid_exit") |> Enum.map(& &1["details"]["utxo_pos"])

    # assert that we can call this testing function reliably
    # FIXME: expand the assertion somehow? introduce `:ok` responses?
    assert [_ | _] = ByzantineEvents.get_many_se_challenges(utxos_to_challenge)
  end

  @tag fixtures: [:perf_test, :child_chain, :omg_watcher]
  test "can provide timing of status.get under many challenged SEs", %{perf_test: {:ok, %{destdir: destdir}}} do
    spenders = Generators.generate_users(2)
    :ok = Performance.start_extended_perftest(100, spenders, %{randomized: true, destdir: destdir})
    :ok = ByzantineEvents.watcher_synchronize()
    alice = Enum.at(spenders, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      ByzantineEvents.Generators.stream_utxo_positions(nil, owned_by: alice.addr)
      |> Enum.take(20)
      |> ByzantineEvents.start_many_exits(alice.addr)

    :ok = ByzantineEvents.watcher_synchronize(last_exit_height)

    # assert we can process the many challenges and get status then
    {:ok, %{"status" => "0x1", "blockNumber" => last_challenge_height}} =
      ByzantineEvents.get_byzantine_events("invalid_exit")
      |> Enum.map(& &1["details"]["utxo_pos"])
      |> ByzantineEvents.get_many_se_challenges()
      |> ByzantineEvents.challenge_many_exits(alice.addr)

    :ok = ByzantineEvents.watcher_synchronize(last_challenge_height)

    assert [] = ByzantineEvents.get_byzantine_events("invalid_exit")
  end
end
