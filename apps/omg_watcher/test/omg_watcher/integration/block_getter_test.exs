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

defmodule OMG.Watcher.Integration.BlockGetterTest do
  @moduledoc """
  This test is intended to be the major smoke/integration test of the Watcher

  It tests whether valid/invalid blocks, deposits and exits are tracked correctly within the Watcher
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.Watcher.Integration.Fixtures
  use Plug.Test
  use Phoenix.ChannelTest

  alias Ecto.Adapters.SQL.Sandbox
  alias OMG.Eth
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Utxo
  alias OMG.Watcher.Event
  alias OMG.Watcher.Integration.BadChildChainServer
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias Support.DevHelper
  alias Support.RootChainHelper
  alias Support.WatcherHelper

  require Utxo

  @timeout 40_000
  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @moduletag :integration
  @moduletag :watcher

  @moduletag timeout: 100_000

  setup do
    :ok = Sandbox.checkout(OMG.WatcherInfo.DB.Repo)
    Sandbox.mode(OMG.WatcherInfo.DB.Repo, {:shared, self()})
    :ok
  end

  @tag timeout: 200_000
  @tag fixtures: [:db_initialized, :root_chain_contract_config, :mix_based_child_chain, :alice, :bob, :alice_deposits, :token]
  test "get the blocks from child chain after sending a transaction and start exit",
       %{alice: alice, bob: bob, token: token, alice_deposits: {deposit_blknum, token_deposit_blknum}} do
    token_addr = Encoding.to_hex(token)

    # utxo from deposit should be available
    assert [%{"blknum" => ^deposit_blknum}, %{"blknum" => ^token_deposit_blknum, "currency" => ^token_addr}] =
             WatcherHelper.get_utxos(alice.addr)

    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 6}, {bob, 3}])
    %{"blknum" => block_nr} = WatcherHelper.submit(tx)

    IntegrationTest.wait_for_block_fetch(block_nr, @timeout)

    assert [%{"blknum" => ^block_nr}] = WatcherHelper.get_utxos(bob.addr)

    assert [
             %{"blknum" => ^token_deposit_blknum},
             %{"blknum" => ^block_nr}
           ] = WatcherHelper.get_utxos(alice.addr)

    # utxos contain extra fields such as `spending_txhash` so we compare only the fields we expect from both.
    fields = ["blknum", "txindex", "oindex", "utxo_pos", "amount", "currency", "owner"]

    exitable_utxos =
      alice.addr
      |> WatcherHelper.get_exitable_utxos()
      |> Enum.map(fn utxo -> Map.take(utxo, fields) end)

    utxos =
      alice.addr
      |> WatcherHelper.get_utxos()
      |> Enum.map(fn utxo -> Map.take(utxo, fields) end)

    assert utxos == exitable_utxos

    %{
      "utxo_pos" => utxo_pos,
      "txbytes" => txbytes,
      "proof" => proof
    } = WatcherHelper.get_exit_data(block_nr, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => exit_eth_height}} =
      RootChainHelper.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    # Here we're waiting for child chain and watcher to process the exits
    IntegrationTest.wait_for_exit_processing(exit_eth_height, @timeout)

    assert [%{"blknum" => ^token_deposit_blknum}] = WatcherHelper.get_utxos(alice.addr)
    # finally alice exits her token deposit
    %{
      "utxo_pos" => utxo_pos,
      "txbytes" => txbytes,
      "proof" => proof
    } = WatcherHelper.get_exit_data(token_deposit_blknum, 0, 0)

    {:ok, %{"status" => "0x1"}} =
      RootChainHelper.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    :ok = IntegrationTest.process_exits(2, token, alice)
    :ok = IntegrationTest.process_exits(1, @eth, alice)

    assert WatcherHelper.get_exitable_utxos(alice.addr) == []
    assert WatcherHelper.get_utxos(alice.addr) == []
  end

  @tag fixtures: [:db_initialized, :root_chain_contract_config, :test_server]
  test "hash of returned block does not match hash submitted to the root chain", %{test_server: context} do
    different_hash = <<0::256>>
    block_with_incorrect_hash = %{OMG.Block.hashed_txs_at([], 1000) | hash: different_hash}

    # from now on the child chain server is broken until end of test
    BadChildChainServer.prepare_route_to_inject_bad_block(
      context,
      block_with_incorrect_hash,
      different_hash
    )

    # checking if both machines and humans learn about the byzantine condition
    assert WatcherHelper.capture_log(fn ->
             {:ok, _txhash} = Eth.submit_block(different_hash, 1, 20_000_000_000)
             IntegrationTest.wait_for_byzantine_events([%Event.InvalidBlock{}.name], @timeout)
           end) =~ inspect({:error, :incorrect_hash})
  end

  @tag fixtures: [:db_initialized, :root_chain_contract_config, :alice, :test_server]
  test "bad transaction with not existing utxo, detected by interactions with State", %{
    alice: alice,
    test_server: context
  } do
    # preparing block with invalid transaction
    recovered = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    block_with_incorrect_transaction = OMG.Block.hashed_txs_at([recovered], 1000)

    # from now on the child chain server is broken until end of test
    BadChildChainServer.prepare_route_to_inject_bad_block(
      context,
      block_with_incorrect_transaction
    )

    invalid_block_hash = block_with_incorrect_transaction.hash

    # checking if both machines and humans learn about the byzantine condition
    assert WatcherHelper.capture_log(fn ->
             {:ok, _txhash} = Eth.submit_block(invalid_block_hash, 1, 20_000_000_000)
             IntegrationTest.wait_for_byzantine_events([%Event.InvalidBlock{}.name], @timeout)
           end) =~ inspect(:tx_execution)
  end

  @tag fixtures: [:db_initialized, :root_chain_contract_config, :stable_alice, :mix_based_child_chain, :token, :stable_alice_deposits, :test_server]
  test "transaction which is using already spent utxo from exit and happened after margin of slow validator(m_sv) causes to emit unchallenged_exit event",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}, test_server: context} do
    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 9}])
    %{"blknum" => exit_blknum} = WatcherHelper.submit(tx)

    # Here we're preparing invalid block
    bad_tx = OMG.TestHelper.create_recovered([{exit_blknum, 0, 0, alice}], @eth, [{alice, 9}])
    bad_block_number = 2_000

    %{hash: bad_block_hash, number: _, transactions: _} =
      bad_block = OMG.Block.hashed_txs_at([bad_tx], bad_block_number)

    # from now on the child chain server is broken until end of test
    BadChildChainServer.prepare_route_to_inject_bad_block(context, bad_block)

    IntegrationTest.wait_for_block_fetch(exit_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = WatcherHelper.get_exit_data(exit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} =
      RootChainHelper.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    # Here we're waiting for passing of margin of slow validator(m_sv)
    exit_processor_sla_margin = Application.fetch_env!(:omg_watcher, :exit_processor_sla_margin)
    DevHelper.wait_for_root_chain_block(eth_height + exit_processor_sla_margin, @timeout)

    # checking if both machines and humans learn about the byzantine condition
    assert WatcherHelper.capture_log(fn ->
             # Here we're manually submitting invalid block to the root chain
             {:ok, _} = Eth.submit_block(bad_block_hash, 2, 1)
             IntegrationTest.wait_for_byzantine_events([%Event.UnchallengedExit{}.name], @timeout)
           end) =~ inspect(:unchallenged_exit)

    # we should still be able to challenge this "unchallenged exit" - just smoke testing the endpoint, details elsewhere
    WatcherHelper.get_exit_challenge(exit_blknum, 0, 0)
  end

  @tag fixtures: [:db_initialized, :root_chain_contract_config, :mix_based_child_chain, :test_server, :stable_alice, :stable_alice_deposits]
  test "operator claimed fees incorrectly (too much | little amount, not collected token)", %{
    stable_alice: alice,
    test_server: context,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    fee_claimer = OMG.Configuration.fee_claimer_address()

    # preparing transactions for a fake block that overclaim fees
    txs = [
      OMG.TestHelper.create_recovered([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 9}]),
      OMG.TestHelper.create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 8}]),
      OMG.TestHelper.create_recovered_fee_tx(1000, fee_claimer, @eth, 3)
    ]

    block_overclaiming_fees = OMG.Block.hashed_txs_at(txs, 1000)

    # from now on the child chain server is broken until end of test
    BadChildChainServer.prepare_route_to_inject_bad_block(
      context,
      block_overclaiming_fees
    )

    # checking if both machines and humans learn about the byzantine condition
    assert WatcherHelper.capture_log(fn ->
             {:ok, _txhash} = Eth.submit_block(block_overclaiming_fees.hash, 1, 20_000_000_000)
             IntegrationTest.wait_for_byzantine_events([%Event.InvalidBlock{}.name], @timeout)
           end) =~ inspect({:tx_execution, :claimed_and_collected_amounts_mismatch})
  end
end
