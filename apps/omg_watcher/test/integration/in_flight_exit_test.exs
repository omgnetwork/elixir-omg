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

defmodule OMG.Watcher.Integration.InFlightExitTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures
  use OMG.API.Integration.Fixtures
  use Plug.Test

  alias OMG.API
  alias OMG.API.State.Transaction
  alias OMG.Eth
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias OMG.Watcher.TestHelper

  @timeout 40_000
  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @moduletag :integration
  # bumping the timeout to two minutes for the tests here, as they do a lot of transactions to Ethereum to test
  @moduletag timeout: 120_000

  @tag fixtures: [:watcher_sandbox, :alice, :bob, :child_chain, :token, :alice_deposits]
  test "in-flight exit competitor is detected by watcher",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    # Bob, we need you (Bob's going to send some Ethereum transactions)
    Eth.DevHelpers.import_unlock_fund(bob)

    # tx1 is submitted then in-flight-exited
    # tx2 is in-flight-exited
    tx1 = API.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 5}])
    tx2 = API.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{bob, 10}])

    assert %{
             "blknum" => blknum,
             "txindex" => 0,
             "txhash" => <<_::256>>
           } = TestHelper.submit(tx1 |> Transaction.Signed.encode())

    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    %Transaction.Signed{raw_tx: raw_tx1} = tx1
    %Transaction.Signed{raw_tx: raw_tx2} = tx2
    raw_tx1_bytes = raw_tx1 |> Transaction.encode()
    raw_tx2_bytes = raw_tx2 |> Transaction.encode()

    get_in_flight_exit_response1 = tx1 |> Transaction.Signed.encode() |> TestHelper.get_in_flight_exit()

    get_in_flight_exit_response2 = tx2 |> Transaction.Signed.encode() |> TestHelper.get_in_flight_exit()

    {:ok, %{"status" => "0x1"}} =
      OMG.Eth.RootChain.in_flight_exit(
        get_in_flight_exit_response1["in_flight_tx"],
        get_in_flight_exit_response1["input_txs"],
        get_in_flight_exit_response1["input_txs_inclusion_proofs"],
        get_in_flight_exit_response1["in_flight_tx_sigs"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      OMG.Eth.RootChain.in_flight_exit(
        get_in_flight_exit_response2["in_flight_tx"],
        get_in_flight_exit_response2["input_txs"],
        get_in_flight_exit_response2["input_txs_inclusion_proofs"],
        get_in_flight_exit_response2["in_flight_tx_sigs"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    # check in-flight exit has started on root chain, wait for finalization
    raw_tx1_hash = Transaction.hash(raw_tx1)
    raw_tx2_hash = Transaction.hash(raw_tx2)
    alice_address = alice.addr

    assert {:ok,
            [
              %{initiator: ^alice_address, tx_hash: ^raw_tx1_hash},
              %{initiator: ^alice_address, tx_hash: ^raw_tx2_hash}
            ]} = OMG.Eth.RootChain.get_in_flight_exit_starts(0, eth_height)

    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)
    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exit_finality_margin + 1)

    ###
    # EVENTS DETECTION
    ###

    # existence of competitors detected by checking if `non_canonical_ife` events exists
    # Also, there should be piggybacks on input/output available
    assert %{
             "byzantine_events" => [
               %{"event" => "non_canonical_ife"},
               %{"event" => "non_canonical_ife"},
               %{"event" => "piggyback_available"}
             ]
           } = TestHelper.success?("/status.get")

    # Check if IFE is recognized as IFE by watcher (kept separate from the above for readability)
    assert %{"in_flight_exits" => [%{}, %{}]} = TestHelper.success?("/status.get")

    ###
    # PIGGYBACK GAME
    ###

    # Do the piggybacks
    {:ok, %{"status" => "0x1"}} =
      OMG.Eth.RootChain.piggyback_in_flight_exit(raw_tx2_bytes, 0, alice.addr)
      |> Eth.DevHelpers.transact_sync!()

    {:ok, %{"status" => "0x1"}} =
      OMG.Eth.RootChain.piggyback_in_flight_exit(raw_tx2_bytes, 4 + 0, bob.addr)
      |> Eth.DevHelpers.transact_sync!()

    # TODO: rest of piggyback game goes here PROBABLY (OMG-313)

    ###
    # CANONICITY GAME
    ###

    # to challenge canonicity, get chain inclusion proof
    assert %{"competing_tx_pos" => 0, "competing_proof" => ""} =
             get_competitor_response = TestHelper.get_in_flight_exit_competitors(raw_tx1_bytes)

    # we'll be using the above response to integrate, but we need to test whether the included tx2, if used to challenge
    # would give us the opportunity to get the inclusion info (since `get_competitor_response` doesn't include that)
    assert %{"competing_tx_pos" => id, "competing_proof" => proof} =
             TestHelper.get_in_flight_exit_competitors(raw_tx2_bytes)

    assert id > 0
    assert proof != ""

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      OMG.Eth.RootChain.challenge_in_flight_exit_not_canonical(
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

    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exit_finality_margin + 1)

    # existence of `non_canonical_ife` and `invalid_ife_challenge` events
    assert %{
             "byzantine_events" => [
               %{"event" => "non_canonical_ife"},
               %{"event" => "invalid_ife_challenge"},
               %{"event" => "piggyback_available"}
             ]
           } = TestHelper.success?("/status.get")

    # now included IFE transaction tx1 is challenged and non-canonical, let's respond
    get_prove_canonical_response = TestHelper.get_prove_canonical(raw_tx1_bytes)

    {:ok, %{"status" => "0x1"}} =
      OMG.Eth.RootChain.respond_to_non_canonical_challenge(
        get_prove_canonical_response["in_flight_txbytes"],
        get_prove_canonical_response["in_flight_tx_pos"],
        get_prove_canonical_response["in_flight_proof"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()
  end

  @tag fixtures: [:watcher_sandbox, :alice, :bob, :child_chain, :token, :alice_deposits]
  test "honest and cooperating users exit in-flight transaction",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)
    exit_period = Application.fetch_env!(:omg_eth, :exit_period_seconds)

    %Transaction.Signed{raw_tx: raw_tx} =
      tx = API.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {bob, 5}])

    get_in_flight_exit_response = tx |> Transaction.Signed.encode() |> TestHelper.get_in_flight_exit()

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      OMG.Eth.RootChain.in_flight_exit(
        get_in_flight_exit_response["in_flight_tx"],
        get_in_flight_exit_response["input_txs"],
        get_in_flight_exit_response["input_txs_inclusion_proofs"],
        get_in_flight_exit_response["in_flight_tx_sigs"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exit_finality_margin + 1)

    assert %{"in_flight_exits" => [%{}]} = TestHelper.success?("/status.get")

    raw_tx_bytes = raw_tx |> Transaction.encode()

    {:ok, %{"status" => "0x1"}} =
      OMG.Eth.RootChain.piggyback_in_flight_exit(raw_tx_bytes, 4 + 1, bob.addr)
      |> Eth.DevHelpers.transact_sync!()

    Process.sleep(2 * exit_period + 10)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      OMG.Eth.RootChain.process_exits(@eth, 0, 3, alice.addr) |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exit_finality_margin + 1)

    %{in_flight_exits: in_flight_exits} = TestHelper.get_status()
    assert in_flight_exits == []
  end

  test "standard exit does not interfere with in-flight exit" do
  end
end
