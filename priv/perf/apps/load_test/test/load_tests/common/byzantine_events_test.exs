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

defmodule LoadTest.Common.ByzantineEventsTest do
  @moduledoc """
  Simple smoke testing of the performance test
  """
  use ExUnit.Case, async: false
  use LoadTest.Performance

  alias LoadTest.ChildChain.Exit

  @moduletag :integration
  @moduletag timeout: 180_000

  @number_of_transactions_to_send 10
  @take 3

  setup_all do
    _ = Exit.add_exit_queue()

    # preventing :erlang.binary_to_existing_atom("last_mined_child_block_timestamp", :utf8) exception
    _ = String.to_atom("last_mined_child_block_timestamp")
    _ = String.to_atom("last_seen_eth_block_number")
    _ = String.to_atom("last_seen_eth_block_timestamp")
    _ = String.to_atom("last_validated_child_block_timestamp")

    {:ok, destdir} = Briefly.create(directory: true, prefix: "temp_results")

    fee_amount = Application.fetch_env!(:load_test, :fee_amount)

    {:ok, %{destdir: destdir, fee_amount: fee_amount}}
  end

  test "can provide timing of response when asking for exit data", %{destdir: destdir, fee_amount: fee_amount} do
    spenders = Generators.generate_users(2)
    alice = Enum.at(spenders, 0)

    :ok =
      ExtendedPerftest.start(@number_of_transactions_to_send, spenders, fee_amount, randomized: false, destdir: destdir)

    :ok = ByzantineEvents.watcher_synchronize()

    utxos = ByzantineEvents.get_exitable_utxos(alice.addr, take: @take)
    ByzantineEvents.get_many_standard_exits(utxos)
  end

  # since we're using the same geth node for all tests, this test is not compatible with the test on line 76
  @tag :skip
  test "can provide timing of status.get under many valid SEs", %{destdir: destdir, fee_amount: fee_amount} do
    spenders = Generators.generate_users(2)
    alice = Enum.at(spenders, 0)

    :ok =
      ExtendedPerftest.start(@number_of_transactions_to_send, spenders, fee_amount, randomized: false, destdir: destdir)

    :ok = ByzantineEvents.watcher_synchronize()

    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      ByzantineEvents.get_exitable_utxos(alice.addr, take: @take)
      |> ByzantineEvents.get_many_standard_exits()
      |> ByzantineEvents.start_many_exits(alice.addr)

    :ok = ByzantineEvents.watcher_synchronize(root_chain_height: last_exit_height)
    # assert that we can call this testing function reliably and that there are no invalid exits
    assert ByzantineEvents.get_byzantine_events("invalid_exit") == []
  end

  test "can provide timing of status.get under many valid/invalid SEs", %{destdir: destdir, fee_amount: fee_amount} do
    spenders = Generators.generate_users(2)
    alice = Enum.at(spenders, 0)

    :ok =
      ExtendedPerftest.start(@number_of_transactions_to_send, spenders, fee_amount, randomized: true, destdir: destdir)

    :ok = ByzantineEvents.watcher_synchronize()

    {:ok, %{"status" => "0x1", "blockNumber" => last_exit_height}} =
      Generators.stream_utxo_positions(owned_by: alice.addr, take: @take)
      |> ByzantineEvents.get_many_standard_exits()
      |> ByzantineEvents.start_many_exits(alice.addr)

    :ok = ByzantineEvents.watcher_synchronize(root_chain_height: last_exit_height)
    # assert that we can call this testing function reliably and that there are some invalid exits there in fact
    assert Enum.count(ByzantineEvents.get_byzantine_events("invalid_exit")) >= @take
  end

  test "can provide timing of challenging", %{destdir: destdir, fee_amount: fee_amount} do
    spenders = Generators.generate_users(2)
    alice = Enum.at(spenders, 0)

    :ok =
      ExtendedPerftest.start(@number_of_transactions_to_send, spenders, fee_amount, randomized: true, destdir: destdir)

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

  test "can provide timing of status.get under many challenged SEs", %{destdir: destdir, fee_amount: fee_amount} do
    spenders = Generators.generate_users(2)
    alice = Enum.at(spenders, 0)

    :ok =
      ExtendedPerftest.start(@number_of_transactions_to_send, spenders, fee_amount, randomized: true, destdir: destdir)

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
