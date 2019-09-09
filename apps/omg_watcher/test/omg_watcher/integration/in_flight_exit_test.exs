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

defmodule OMG.Watcher.Integration.InFlightExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.ChildChain.Integration.Fixtures
  use Plug.Test

  alias OMG.Eth
  alias OMG.Transaction
  alias OMG.Watcher.Event
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias OMG.Watcher.TestHelper

  alias OMG.Integration.DepositHelper

  @timeout 40_000
  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @moduletag :integration
  @moduletag :watcher
  # bumping the timeout to two minutes for the tests here, as they do a lot of transactions to Ethereum to test
  @moduletag timeout: 180_000

  @tag fixtures: [:watcher, :alice, :bob, :child_chain]
  test "piggyback in flight exit", %{alice: alice, bob: bob} do
    {:ok, _} = Eth.DevHelpers.import_unlock_fund(alice)
    {:ok, _} = Eth.DevHelpers.import_unlock_fund(bob)

    alice_deposit = DepositHelper.deposit_to_child_chain(alice.addr, 10)

    bob_deposit = DepositHelper.deposit_to_child_chain(bob.addr, 10)

    tx_submit1 =
      OMG.TestHelper.create_signed(
        [{alice_deposit, 0, 0, alice}, {bob_deposit, 0, 0, bob}],
        @eth,
        [{alice, 5}, {bob, 15}]
      )

    # To create in-flight exit watcher need have available utxo in his state,
    # otherwise the watcher state indicates that there is no need to do in_flight_exit.
    in_flight_tx =
      OMG.TestHelper.create_signed([{bob_deposit, 0, 0, bob}], @eth, [{bob, 5}])
      |> Transaction.Signed.encode()
      |> TestHelper.get_in_flight_exit()

    # Submit tx 1
    %{"blknum" => blknum} = TestHelper.submit(tx_submit1 |> Transaction.Signed.encode())

    # Submit tx 2
    TestHelper.submit(
      OMG.TestHelper.create_signed([{blknum, 0, 1, bob}], @eth, [{alice, 2}, {alice, 3}])
      |> Transaction.Signed.encode()
    )

    {:ok, %{"status" => "0x1"}} = exit_in_flight(tx_submit1, alice)

    txbytes1 = OMG.Transaction.Extract.raw_txbytes(tx_submit1)
    {:ok, ife_id} = OMG.Eth.RootChain.get_in_flight_exit_id(txbytes1)
    # sanity check
    {:ok, {_, _, 0, _, _}} = OMG.Eth.RootChain.get_in_flight_exit(ife_id)

    # PB 1
    {:ok, %{"status" => "0x1"}} =
      OMG.Eth.RootChainHelper.piggyback_in_flight_exit(OMG.Transaction.Extract.raw_txbytes(tx_submit1), 5, bob.addr)
      |> Eth.DevHelpers.transact_sync!()

    # PB 2
    {:ok, %{"status" => "0x1"}} =
      OMG.Eth.RootChainHelper.piggyback_in_flight_exit(OMG.Transaction.Extract.raw_txbytes(tx_submit1), 1, bob.addr)
      |> Eth.DevHelpers.transact_sync!()

    # sanity check
    {:ok, {_, _, exitmap, _, _}} = OMG.Eth.RootChain.get_in_flight_exit(ife_id)
    assert exitmap != 0
    # IFE tx 3
    {:ok, %{"status" => "0x1"}} =
      OMG.Eth.RootChainHelper.in_flight_exit(
        in_flight_tx["in_flight_tx"],
        in_flight_tx["input_txs"],
        in_flight_tx["input_txs_inclusion_proofs"],
        in_flight_tx["in_flight_tx_sigs"],
        bob.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    # ask for byzantine events first, learn both piggybacks are invalid
    # wait for NonCanonicalIFE (waiting for invalid piggyback is flaky)
    {:ok, _} = IntegrationTest.wait_for_byzantine_events([%Event.NonCanonicalIFE{}.name], @timeout)

    # make sure that list of byzantine events is as expected
    assert %{
             "byzantine_events" => [
               %{"event" => "invalid_piggyback"},
               # only a single non_canonical event, since on of the IFE tx is included!
               %{"event" => "non_canonical_ife"},
               # only piggyback_available for tx2 is present, tx1 is included in block and does not spawn that event
               %{"event" => "piggyback_available"}
             ]
           } = TestHelper.success?("/status.get")

    # ask for proofs
    txbytes_raw1 = tx_submit1 |> OMG.Transaction.Extract.raw_txbytes()
    assert %{"in_flight_txbytes" => ^txbytes_raw1} = proof1 = TestHelper.get_input_challenge_data(txbytes_raw1, 1)
    # challenge piggybacks
    {:ok, %{"status" => "0x1"}} =
      OMG.Eth.RootChainHelper.challenge_in_flight_exit_input_spent(
        proof1["in_flight_txbytes"],
        proof1["in_flight_input_index"],
        proof1["spending_txbytes"],
        proof1["spending_input_index"],
        proof1["spending_sig"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    # sanity check
    {:ok, {_, _, exitmap1, _, _}} = OMG.Eth.RootChain.get_in_flight_exit(ife_id)
    assert exitmap1 != exitmap
    assert exitmap1 != 0

    assert %{
             "in_flight_txbytes" => ^txbytes_raw1,
             "in_flight_output_pos" => in_flight_output_pos,
             "in_flight_proof" => in_flight_proof,
             "spending_txbytes" => spending_txbytes,
             "spending_input_index" => spending_input_index,
             "spending_sig" => spending_sig
           } = TestHelper.get_output_challenge_data(txbytes_raw1, 1)

    {:ok, %{"status" => "0x1"}} =
      OMG.Eth.RootChainHelper.challenge_in_flight_exit_output_spent(
        txbytes_raw1,
        in_flight_output_pos,
        in_flight_proof,
        spending_txbytes,
        spending_input_index,
        spending_sig,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    # observe the result - piggybacks are gone
    assert {:ok, {_, _, 0, _, _}} = OMG.Eth.RootChain.get_in_flight_exit(ife_id)
  end

  @tag fixtures: [:watcher, :alice, :bob, :child_chain, :token, :alice_deposits]
  test "in-flight exit competitor is detected by watcher and proven with position immediately",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    # tx1 is submitted then in-flight-exited
    # tx2 is in-flight-exited
    tx1 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 5}])
    tx2 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{bob, 10}])

    ife1 = tx1 |> Transaction.Signed.encode() |> TestHelper.get_in_flight_exit()
    ife2 = tx2 |> Transaction.Signed.encode() |> TestHelper.get_in_flight_exit()

    assert %{
             "blknum" => blknum,
             "txindex" => 0,
             "txhash" => <<_::256>>
           } = TestHelper.submit(tx1 |> Transaction.Signed.encode())

    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    raw_tx2_bytes = tx2 |> OMG.Transaction.Extract.raw_txbytes()

    {:ok, %{"status" => "0x1", "blockNumber" => _}} = exit_in_flight(ife1, alice)
    {:ok, %{"status" => "0x1", "blockNumber" => ife_eth_height}} = exit_in_flight(ife2, alice)
    # sanity check in-flight exit has started on root chain, wait for finality
    assert {:ok, [_, _]} = OMG.Eth.RootChain.get_in_flight_exit_starts(0, ife_eth_height)

    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)
    Eth.DevHelpers.wait_for_root_chain_block(ife_eth_height + exit_finality_margin + 1)

    ###
    # EVENTS DETECTION
    ###

    # existence of competitors detected by checking if `non_canonical_ife` events exists
    # Also, there should be piggybacks on input/output available
    assert %{
             "byzantine_events" => [
               # only a single non_canonical event, since on of the IFE tx is included!
               %{"event" => "non_canonical_ife"},
               %{"event" => "piggyback_available"}
             ]
           } = TestHelper.success?("/status.get")

    # Check if IFE is recognized as IFE by watcher (kept separate from the above for readability)
    assert %{"in_flight_exits" => [%{}, %{}]} = TestHelper.success?("/status.get")

    ###
    # CANONICITY GAME
    ###

    assert %{"competing_tx_pos" => id, "competing_proof" => proof} =
             get_competitor_response = TestHelper.get_in_flight_exit_competitors(raw_tx2_bytes)

    assert id > 0
    assert proof != ""

    {:ok, %{"status" => "0x1", "blockNumber" => challenge_eth_height}} =
      OMG.Eth.RootChainHelper.challenge_in_flight_exit_not_canonical(
        get_competitor_response["in_flight_txbytes"],
        get_competitor_response["in_flight_input_index"],
        get_competitor_response["competing_txbytes"],
        get_competitor_response["competing_input_index"],
        get_competitor_response["competing_tx_pos"],
        get_competitor_response["competing_proof"],
        get_competitor_response["competing_sig"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(challenge_eth_height + exit_finality_margin + 1)

    # vanishing of `non_canonical_ife` event
    assert %{"byzantine_events" => [%{"event" => "piggyback_available"}]} = TestHelper.success?("/status.get")
  end

  @tag fixtures: [:watcher, :alice, :bob, :child_chain, :token, :alice_deposits]
  test "invalid in-flight exit challenge is detected by watcher, because it contains no position",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    # tx1 is submitted then in-flight-exited
    # tx2 is in-flight-exited, it will be _invalidly_ used to challenge tx1!
    tx1 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 5}])
    tx2 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{bob, 10}])

    ife1 = tx1 |> Transaction.Signed.encode() |> TestHelper.get_in_flight_exit()
    ife2 = tx2 |> Transaction.Signed.encode() |> TestHelper.get_in_flight_exit()

    assert %{
             "blknum" => blknum,
             "txindex" => 0,
             "txhash" => <<_::256>>
           } = TestHelper.submit(tx1 |> Transaction.Signed.encode())

    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    raw_tx1_bytes = tx1 |> OMG.Transaction.Extract.raw_txbytes()
    raw_tx2_bytes = tx2 |> OMG.Transaction.Extract.raw_txbytes()

    {:ok, %{"status" => "0x1", "blockNumber" => _}} = exit_in_flight(ife1, alice)
    {:ok, %{"status" => "0x1", "blockNumber" => ife_eth_height}} = exit_in_flight(ife2, alice)
    # sanity check in-flight exit has started on root chain, wait for finality
    assert {:ok, [_, _]} = OMG.Eth.RootChain.get_in_flight_exit_starts(0, ife_eth_height)
    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)
    Eth.DevHelpers.wait_for_root_chain_block(ife_eth_height + exit_finality_margin + 1)

    # EVENTS DETECTION (tested in the other test, skipping)
    # Check if IFE is recognized (tested in the other test, skipping)

    ###
    # CANONICITY GAME
    ###

    # we're unable to get the invalid challenge using `in_flight_exit.get_competitor`!
    # ...so we need to stich it together from some pieces we have:
    %{sigs: [competing_sig | _]} = tx2

    {:ok, %{"status" => "0x1", "blockNumber" => challenge_eth_height}} =
      OMG.Eth.RootChainHelper.challenge_in_flight_exit_not_canonical(
        raw_tx1_bytes,
        0,
        raw_tx2_bytes,
        0,
        0,
        "",
        competing_sig,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(challenge_eth_height + exit_finality_margin + 1)

    # existence of `invalid_ife_challenge` event
    assert %{
             "byzantine_events" => [
               # this is the tx2's non-canonical-ife which we leave as is
               %{"event" => "non_canonical_ife"},
               %{"event" => "invalid_ife_challenge"},
               %{"event" => "piggyback_available"}
             ]
           } = TestHelper.success?("/status.get")

    # now included IFE transaction tx1 is challenged and non-canonical, let's respond
    get_prove_canonical_response = TestHelper.get_prove_canonical(raw_tx1_bytes)

    {:ok, %{"status" => "0x1", "blockNumber" => response_eth_height}} =
      OMG.Eth.RootChainHelper.respond_to_non_canonical_challenge(
        get_prove_canonical_response["in_flight_txbytes"],
        get_prove_canonical_response["in_flight_tx_pos"],
        get_prove_canonical_response["in_flight_proof"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(response_eth_height + exit_finality_margin + 1)

    # dissapearing of `invalid_ife_challenge` event
    assert %{"byzantine_events" => [%{"event" => "non_canonical_ife"}, %{"event" => "piggyback_available"}]} =
             TestHelper.success?("/status.get")
  end

  @tag fixtures: [:watcher, :alice, :bob, :child_chain, :token, :alice_deposits]
  test "honest and cooperating users exit in-flight transaction",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    Eth.DevHelpers.import_unlock_fund(bob)

    tx = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {bob, 5}])
    ife1 = tx |> Transaction.Signed.encode() |> TestHelper.get_in_flight_exit()

    %{"blknum" => blknum} = TestHelper.submit(tx |> Transaction.Signed.encode())
    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    _ = exit_in_flight_and_wait_for_ife(ife1, alice)

    assert %{"in_flight_exits" => [%{}]} = TestHelper.success?("/status.get")

    _ = piggyback_and_process_exits(tx, 4 + 1, bob)

    assert %{"in_flight_exits" => [], "byzantine_events" => []} = TestHelper.success?("/status.get")
  end

  @tag fixtures: [:watcher, :alice, :bob, :child_chain, :token, :alice_deposits]
  test "finalization of utxo not recognized in state leaves in-flight exit active",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    Eth.DevHelpers.import_unlock_fund(bob)

    tx = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {bob, 5}])

    _ = exit_in_flight_and_wait_for_ife(tx, alice)
    _ = piggyback_and_process_exits(tx, 4 + 1, bob)

    assert %{"in_flight_exits" => [_], "byzantine_events" => [_]} = TestHelper.success?("/status.get")
  end

  defp exit_in_flight(%Transaction.Signed{} = tx, exiting_user) do
    get_in_flight_exit_response = tx |> Transaction.Signed.encode() |> TestHelper.get_in_flight_exit()
    exit_in_flight(get_in_flight_exit_response, exiting_user)
  end

  defp exit_in_flight(get_in_flight_exit_response, exiting_user) do
    OMG.Eth.RootChainHelper.in_flight_exit(
      get_in_flight_exit_response["in_flight_tx"],
      get_in_flight_exit_response["input_txs"],
      get_in_flight_exit_response["input_txs_inclusion_proofs"],
      get_in_flight_exit_response["in_flight_tx_sigs"],
      exiting_user.addr
    )
    |> Eth.DevHelpers.transact_sync!()
  end

  defp exit_in_flight_and_wait_for_ife(tx, exiting_user) do
    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} = exit_in_flight(tx, exiting_user)
    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)
    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exit_finality_margin + 1)
  end

  defp piggyback_and_process_exits(%Transaction.Signed{raw_tx: raw_tx}, output, output_owner) do
    raw_tx_bytes = raw_tx |> OMG.Transaction.Extract.raw_txbytes()

    {:ok, _} =
      OMG.Eth.RootChainHelper.piggyback_in_flight_exit(raw_tx_bytes, output, output_owner.addr)
      |> Eth.DevHelpers.transact_sync!()

    exit_period = Application.fetch_env!(:omg_eth, :exit_period_seconds) * 1_000
    Process.sleep(2 * exit_period + 5_000)

    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      OMG.Eth.RootChainHelper.process_exits(@eth, 0, 1, output_owner.addr) |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exit_finality_margin + 10)
  end
end
