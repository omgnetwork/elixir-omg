# Copyright 2019-2020 OmiseGO Pte Ltd
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
  @moduledoc """
  Simple smoke testing of the performance test
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.ChildChain.Integration.Fixtures
  use OMG.Watcher.Fixtures

  use OMG.Performance

  @moduletag :integration
  @moduletag timeout: 180_000

  @number_of_transactions_to_send 10
  @take 3

  setup_all do
    # preventing :erlang.binary_to_existing_atom("last_mined_child_block_timestamp", :utf8) exception
    _ = String.to_atom("last_mined_child_block_timestamp")
    _ = String.to_atom("last_seen_eth_block_number")
    _ = String.to_atom("last_seen_eth_block_timestamp")
    _ = String.to_atom("last_validated_child_block_timestamp")
    :ok
  end

  # NOTE: still bound to fixtures :(, because of the child chain setup, but this will go eventually, so leaving as is
  deffixture perf_test(contract) do
    _ = contract
    :ok = Performance.init()
    {:ok, destdir} = Briefly.create(directory: true, prefix: "temp_results")
    {:ok, %{destdir: destdir}}
  end

  @tag fixtures: [:perf_test, :mix_based_child_chain, :mix_based_watcher]
  test "can provide timing of response when asking for exit data", %{perf_test: {:ok, %{destdir: destdir}}} do
    spenders = Generators.generate_users(2)
    alice = Enum.at(spenders, 0)

    :ok =
      Performance.ExtendedPerftest.start(@number_of_transactions_to_send, spenders, randomized: false, destdir: destdir)

    :ok = ByzantineEvents.watcher_synchronize()

    utxos = ByzantineEvents.get_exitable_utxos(alice.addr, take: @take)
    ByzantineEvents.get_many_standard_exits(utxos)
  end

  @tag fixtures: [:perf_test, :mix_based_child_chain, :mix_based_watcher]
  test "can provide timing of status.get under many valid SEs", %{perf_test: {:ok, %{destdir: destdir}}} do
    spenders = Generators.generate_users(2)
    alice = Enum.at(spenders, 0)

    :ok =
      Performance.ExtendedPerftest.start(@number_of_transactions_to_send, spenders, randomized: false, destdir: destdir)

    :ok = ByzantineEvents.watcher_synchronize()

    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      ByzantineEvents.get_exitable_utxos(alice.addr, take: @take)
      |> ByzantineEvents.get_many_standard_exits()
      |> ByzantineEvents.start_many_exits(alice.addr)

    :ok = ByzantineEvents.watcher_synchronize(root_chain_height: last_exit_height)
    # assert that we can call this testing function reliably and that there are no invalid exits
    assert ByzantineEvents.get_byzantine_events("invalid_exit") == []
  end

  @tag fixtures: [:perf_test, :mix_based_child_chain, :mix_based_watcher]
  test "can provide timing of status.get under many valid/invalid SEs", %{perf_test: {:ok, %{destdir: destdir}}} do
    spenders = Generators.generate_users(2)
    alice = Enum.at(spenders, 0)

    :ok =
      Performance.ExtendedPerftest.start(@number_of_transactions_to_send, spenders, randomized: true, destdir: destdir)

    :ok = ByzantineEvents.watcher_synchronize()

    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      Generators.stream_utxo_positions(owned_by: alice.addr, take: @take)
      |> ByzantineEvents.get_many_standard_exits()
      |> ByzantineEvents.start_many_exits(alice.addr)

    :ok = ByzantineEvents.watcher_synchronize(root_chain_height: last_exit_height)
    # assert that we can call this testing function reliably and that there are some invalid exits there in fact
    assert Enum.count(ByzantineEvents.get_byzantine_events("invalid_exit")) >= @take
  end

  @tag fixtures: [:perf_test, :mix_based_child_chain, :mix_based_watcher]
  test "can provide timing of challenging", %{perf_test: {:ok, %{destdir: destdir}}} do
    spenders = Generators.generate_users(2)
    alice = Enum.at(spenders, 0)

    :ok =
      Performance.ExtendedPerftest.start(@number_of_transactions_to_send, spenders, randomized: true, destdir: destdir)

    :ok = ByzantineEvents.watcher_synchronize()

    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      Generators.stream_utxo_positions(owned_by: alice.addr, take: @take)
      |> ByzantineEvents.get_many_standard_exits()
      |> ByzantineEvents.start_many_exits(alice.addr)

    :ok = ByzantineEvents.watcher_synchronize(root_chain_height: last_exit_height)

    utxos_to_challenge = ByzantineEvents.get_byzantine_events("invalid_exit")

    # assert that we can call this testing function reliably
    assert challenge_responses = ByzantineEvents.get_many_se_challenges(utxos_to_challenge)

    assert Enum.count(challenge_responses) == Enum.count(utxos_to_challenge)
    assert Enum.count(challenge_responses) >= @take
  end

  @tag fixtures: [:perf_test, :mix_based_child_chain, :mix_based_watcher]
  test "can provide timing of status.get under many challenged SEs", %{perf_test: {:ok, %{destdir: destdir}}} do
    spenders = Generators.generate_users(2)
    alice = Enum.at(spenders, 0)

    :ok =
      Performance.ExtendedPerftest.start(@number_of_transactions_to_send, spenders, randomized: true, destdir: destdir)

    :ok = ByzantineEvents.watcher_synchronize()

    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      Generators.stream_utxo_positions(owned_by: alice.addr, take: @take)
      |> ByzantineEvents.get_many_standard_exits()
      |> ByzantineEvents.start_many_exits(alice.addr)

    :ok = ByzantineEvents.watcher_synchronize(root_chain_height: last_exit_height)

    # assert we can process the many challenges and get status then
    {:ok, %{"status" => "0x1", "blockNumber" => last_challenge_height}} =
      ByzantineEvents.get_byzantine_events("invalid_exit")
      |> ByzantineEvents.get_many_se_challenges()
      |> ByzantineEvents.challenge_many_exits(alice.addr)

    :ok = ByzantineEvents.watcher_synchronize(root_chain_height: last_challenge_height)

    assert ByzantineEvents.get_byzantine_events("invalid_exit") == []
  end
end
