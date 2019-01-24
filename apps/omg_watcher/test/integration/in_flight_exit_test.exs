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

defmodule OMG.Watcher.Integration.WatcherApiTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures
  use OMG.API.Integration.Fixtures
  use Plug.Test

  alias OMG.API
  alias OMG.API.Crypto
  alias OMG.API.Integration.DepositHelper
  alias OMG.API.State.Transaction
  alias OMG.Eth
  alias OMG.RPC.Client
  alias OMG.RPC.Web.Encoding
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias OMG.Watcher.TestHelper

  @timeout 40_000
  @eth Crypto.zero_address()

  @moduletag :integration

  @tag fixtures: [:watcher_sandbox, :alice, :child_chain, :alice_deposits]
  @tag timeout: 120_000
  test "in-flight exit data returned by watcher http API produces a valid in-flight exit",
       %{alice: alice, alice_deposits: {deposit_blknum, _}} do
    # NOTE: this test is here to assert valid behavior of the child chain when exits are filed in the root chain
    #       contract. See `integration/block_getter_test.exs` for another example of this
    # TODO: After this is moved to child-chain specific tests, this test can be removed as duplicate with the other
    #       integration test. (resp task OMG-379) **MAKE SURE IT DOESN'T TEST ANYTHING THE NEXT SCENARIO DOESN'T**

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 5}])
    {:ok, %{blknum: blknum, txindex: txindex}} = Client.submit(tx)

    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    %Transaction.Signed{raw_tx: raw_in_flight_tx} =
      in_flight_tx =
      API.TestHelper.create_signed([{blknum, txindex, 0, alice}, {blknum, txindex, 1, alice}], @eth, [{alice, 10}])

    in_flight_txbytes =
      in_flight_tx
      |> Transaction.Signed.encode()
      |> OMG.RPC.Web.Encoding.to_hex()

    %{
      "in_flight_tx" => in_flight_tx,
      "in_flight_tx_sigs" => in_flight_tx_sigs,
      "input_txs" => input_txs,
      "input_txs_inclusion_proofs" => input_txs_inclusion_proofs
    } = TestHelper.get_in_flight_exit(in_flight_txbytes)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      OMG.Eth.RootChain.in_flight_exit(
        in_flight_tx,
        input_txs,
        input_txs_inclusion_proofs,
        in_flight_tx_sigs,
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    in_flight_tx_hash = Transaction.hash(raw_in_flight_tx)
    alice_address = alice.addr

    assert {:ok, [%{initiator: ^alice_address, tx_hash: ^in_flight_tx_hash}]} =
             OMG.Eth.RootChain.get_in_flight_exit_starts(0, eth_height)

    exiters_finality_margin = Application.fetch_env!(:omg_api, :exiters_finality_margin) + 1
    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exiters_finality_margin)

    tx_double_spend = API.TestHelper.create_encoded([{blknum, txindex, 0, alice}], @eth, [{alice, 2}, {alice, 3}])
    assert {:error, {:client_error, %{"code" => "submit:utxo_not_found"}}} = Client.submit(tx_double_spend)

    deposit_blknum = DepositHelper.deposit_to_child_chain(alice.addr, 10)
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {alice, 3}])
    {:ok, %{blknum: tx_blknum, txhash: _tx_hash}} = Client.submit(tx)

    in_flight_exit_info =
      tx
      |> OMG.RPC.Web.Encoding.to_hex()
      |> TestHelper.get_in_flight_exit()

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      Eth.RootChain.in_flight_exit(
        in_flight_exit_info["in_flight_tx"],
        in_flight_exit_info["input_txs"],
        in_flight_exit_info["input_txs_inclusion_proofs"],
        in_flight_exit_info["in_flight_tx_sigs"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exiters_finality_margin)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      Eth.RootChain.piggyback_in_flight_exit(in_flight_exit_info["in_flight_tx"], 4, alice.addr)
      |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exiters_finality_margin)

    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {alice, 3}])
    assert {:error, {:client_error, %{"code" => "submit:utxo_not_found"}}} = Client.submit(tx)

    tx = API.TestHelper.create_encoded([{tx_blknum, 0, 0, alice}], @eth, [{alice, 7}])
    assert {:error, {:client_error, %{"code" => "submit:utxo_not_found"}}} = Client.submit(tx)

    tx = API.TestHelper.create_encoded([{tx_blknum, 0, 1, alice}], @eth, [{alice, 3}])
    assert {:ok, _} = Client.submit(tx)
  end

  @tag fixtures: [:watcher_sandbox, :alice, :bob, :child_chain, :token, :alice_deposits]
  test "in-flight exit competitor is detected by watcher",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    # tx1 is submitted then in-flight-exited
    # tx2 is in-flight-exited
    tx1 = API.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 5}])
    tx2 = API.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{bob, 10}])

    {:ok, %{blknum: blknum}} = Client.submit(tx1 |> Transaction.Signed.encode())

    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    %Transaction.Signed{raw_tx: raw_tx1} = tx1
    %Transaction.Signed{raw_tx: raw_tx2} = tx2
    raw_tx1_bytes = raw_tx1 |> Transaction.encode() |> Encoding.to_hex()
    raw_tx2_bytes = raw_tx2 |> Transaction.encode() |> Encoding.to_hex()

    get_in_flight_exit_response1 =
      tx1 |> Transaction.Signed.encode() |> Encoding.to_hex() |> TestHelper.get_in_flight_exit()

    get_in_flight_exit_response2 =
      tx2 |> Transaction.Signed.encode() |> Encoding.to_hex() |> TestHelper.get_in_flight_exit()

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

    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)
    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exit_finality_margin + 1)

    # is existence of competitors detected?
    assert %{
             "byzantine_events" => [%{"event" => "non_canonical_ife"}, %{"event" => "non_canonical_ife"}]
           } = TestHelper.success?("/status.get")

    # Check if IFE is recognized as IFE by watcher.
    # TODO: uncomment test after `"inflight_exits"` field is delivered
    # assert %{
    #          "inflight_exits" => [%{"txbytes" => ^raw_tx2_bytes}]
    #        } = TestHelper.success?("/status.get")

    # TODO: Check if watcher proposes piggyback based only on state of the contract
    #       or on state of contract and local store

    # There should be piggybacks on input/output available
    # NOTE: (we disregard canonicity for now)
    # TODO: uncomment assertions when OMG-310/OMG-311 are done
    # assert %{
    #          "byzantine_events" => events
    #        } = TestHelper.success?("/status.get")
    #
    # assert [%{"details" => %{"available_outputs" => outputs_list}}] =
    #          Enum.filter(events, fn %{"event" => "piggyback_available"} -> true end)
    #
    # bob_hex =  Encoding.to_hex(bob.addr)
    # assert [%{"index" => 0, address: ^bob_hex} | _] = outputs_list

    # Do the piggyback on the output.
    # {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
    #   OMG.Eth.RootChain.piggyback_in_flight_exit(raw_tx2_bytes, 4 + 0, bob)

    # TODO: OMG-311
    # alice_hex =  Encoding.to_hex(alice.addr)
    # assert [%{"index" => 0, address: ^alice_hex} | _] = outputs_list

    # Do the piggyback on the input.
    # {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
    #   OMG.Eth.RootChain.piggyback_in_flight_exit(tx2_bytes, 0, alice)

    # to challenge canonicity, get chain inclusion proof
    assert %{"competing_txid" => 0, "competing_proof" => ""} =
             get_competitor_response = TestHelper.get_in_flight_exit_competitors(raw_tx1_bytes)

    # we'll be using the above response to integrate, but we need to test whether the included tx2, if used to challenge
    # would give us the opportunity to get the inclusion info (since `get_competitor_response` doesn't include that)
    assert %{"competing_txid" => id, "competing_proof" => proof} =
             TestHelper.get_in_flight_exit_competitors(raw_tx2_bytes)

    assert id > 0
    assert proof != ""

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      OMG.Eth.RootChain.challenge_in_flight_exit_not_canonical(
        get_competitor_response["inflight_txbytes"],
        get_competitor_response["inflight_input_index"],
        get_competitor_response["competing_txbytes"],
        get_competitor_response["competing_input_index"],
        get_competitor_response["competing_txid"],
        get_competitor_response["competing_proof"],
        get_competitor_response["competing_sig"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()

    Eth.DevHelpers.wait_for_root_chain_block(eth_height + exit_finality_margin + 1)

    assert %{
             "byzantine_events" => [%{"event" => "non_canonical_ife"}, %{"event" => "invalid_ife_challenge"}]
           } = TestHelper.success?("/status.get")

    # now included IFE transaction tx1 is challenged and non-canonical, let's respond
    get_prove_canonical_response = TestHelper.get_prove_canonical(raw_tx1_bytes)

    {:ok, %{"status" => "0x1"}} =
      OMG.Eth.RootChain.respond_to_non_canonical_challenge(
        get_prove_canonical_response["inflight_txbytes"],
        get_prove_canonical_response["inflight_txid"],
        get_prove_canonical_response["inflight_proof"],
        alice.addr
      )
      |> Eth.DevHelpers.transact_sync!()
  end
end
