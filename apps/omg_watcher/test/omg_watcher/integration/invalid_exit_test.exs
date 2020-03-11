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

defmodule OMG.Watcher.Integration.InvalidExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.ChildChain.Integration.Fixtures
  use Plug.Test

  alias OMG.Utxo
  alias OMG.Watcher.Event
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias Support.DevHelper
  alias Support.RootChainHelper
  alias Support.WatcherHelper

  require Utxo

  @moduletag :integration
  @moduletag :watcher
  @moduletag timeout: 120_000

  @timeout 40_000
  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:in_beam_watcher, :stable_alice, :mix_based_child_chain, :token, :stable_alice_deposits]
  test "exit which is using already spent utxo from transaction and deposit causes to emit invalid_exit event", %{
    stable_alice: alice,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    %{"txbytes" => deposit_txbytes, "proof" => deposit_proof, "utxo_pos" => deposit_utxo_pos} =
      WatcherHelper.get_exit_data(deposit_blknum, 0, 0)

    %{"blknum" => first_tx_blknum} =
      OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 9}]) |> WatcherHelper.submit()

    %{"blknum" => second_tx_blknum} =
      OMG.TestHelper.create_encoded([{first_tx_blknum, 0, 0, alice}], @eth, [{alice, 8}]) |> WatcherHelper.submit()

    IntegrationTest.wait_for_block_fetch(second_tx_blknum, @timeout)

    %{"txbytes" => txbytes, "proof" => proof, "utxo_pos" => tx_utxo_pos} =
      WatcherHelper.get_exit_data(first_tx_blknum, 0, 0)

    {:ok, %{"status" => "0x1"}} =
      RootChainHelper.start_exit(tx_utxo_pos, txbytes, proof, alice.addr)
      |> DevHelper.transact_sync!()

    {:ok, %{"status" => "0x1"}} =
      RootChainHelper.start_exit(deposit_utxo_pos, deposit_txbytes, deposit_proof, alice.addr)
      |> DevHelper.transact_sync!()

    IntegrationTest.wait_for_byzantine_events([%Event.InvalidExit{}.name, %Event.InvalidExit{}.name], @timeout)

    # after the notification has been received, a challenged is composed and sent
    challenge = WatcherHelper.get_exit_challenge(first_tx_blknum, 0, 0)

    assert {:ok, %{"status" => "0x1"}} =
             RootChainHelper.challenge_exit(
               challenge["exit_id"],
               challenge["exiting_tx"],
               challenge["txbytes"],
               challenge["input_index"],
               challenge["sig"],
               alice.addr
             )
             |> DevHelper.transact_sync!()

    # challenge standard exits from deposits
    challenge_exit_deposit = WatcherHelper.get_exit_challenge(deposit_blknum, 0, 0)

    assert {:ok, %{"status" => "0x1"}} =
             RootChainHelper.challenge_exit(
               challenge_exit_deposit["exit_id"],
               challenge_exit_deposit["exiting_tx"],
               challenge_exit_deposit["txbytes"],
               challenge_exit_deposit["input_index"],
               challenge_exit_deposit["sig"],
               alice.addr
             )
             |> DevHelper.transact_sync!()

    IntegrationTest.wait_for_byzantine_events([], @timeout)
  end

  @tag fixtures: [:in_beam_watcher, :stable_alice, :mix_based_child_chain, :token, :stable_alice_deposits]
  test "invalid_exit without a challenge raises unchallenged_exit after sla_margin had passed, can be challenged",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}} do
    %{"blknum" => first_tx_blknum} =
      OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 9}]) |> WatcherHelper.submit()

    %{"blknum" => second_tx_blknum} =
      OMG.TestHelper.create_encoded([{first_tx_blknum, 0, 0, alice}], @eth, [{alice, 8}]) |> WatcherHelper.submit()

    IntegrationTest.wait_for_block_fetch(second_tx_blknum, @timeout)

    %{"txbytes" => txbytes, "proof" => proof, "utxo_pos" => tx_utxo_pos} =
      WatcherHelper.get_exit_data(first_tx_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      RootChainHelper.start_exit(tx_utxo_pos, txbytes, proof, alice.addr)
      |> DevHelper.transact_sync!()

    IntegrationTest.wait_for_byzantine_events([%Event.InvalidExit{}.name], @timeout)

    exit_processor_sla_margin = Application.fetch_env!(:omg_watcher, :exit_processor_sla_margin)
    DevHelper.wait_for_root_chain_block(eth_height + exit_processor_sla_margin, @timeout)
    IntegrationTest.wait_for_byzantine_events([%Event.InvalidExit{}.name, %Event.UnchallengedExit{}.name], @timeout)

    # after the notification has been received, a challenged is composed and sent, regardless of it being late
    challenge = WatcherHelper.get_exit_challenge(first_tx_blknum, 0, 0)

    assert {:ok, %{"status" => "0x1"}} =
             RootChainHelper.challenge_exit(
               challenge["exit_id"],
               challenge["exiting_tx"],
               challenge["txbytes"],
               challenge["input_index"],
               challenge["sig"],
               alice.addr
             )
             |> DevHelper.transact_sync!()

    IntegrationTest.wait_for_byzantine_events([], @timeout)
  end
end
