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

  require OMG.Utxo

  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias OMG.Eth
  alias OMG.Watcher.BlockGetter
  alias OMG.Watcher.Event
  alias OMG.Watcher.Integration.BadChildChainServer
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias Support.DevHelper
  alias Support.RootChainHelper
  alias Support.WatcherHelper

  @timeout 40_000
  @eth OMG.Eth.zero_address()
  @hex_eth "0x0000000000000000000000000000000000000000"

  @moduletag :integration
  @moduletag :watcher

  @moduletag timeout: 100_000

  @tag timeout: 200_000
  @tag fixtures: [:in_beam_watcher, :mix_based_child_chain, :alice, :bob, :alice_deposits, :token]
  test "get the blocks from child chain after sending a transaction and start exit",
       %{alice: alice, bob: bob, token: token, alice_deposits: {deposit_blknum, token_deposit_blknum}} do
    # utxo from deposit should be available
    assert [%{"blknum" => ^deposit_blknum}, %{"blknum" => ^token_deposit_blknum, "currency" => ^token}] =
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
      %{address: alice.addr}
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
    :ok = IntegrationTest.process_exits(1, @hex_eth, alice)

    assert WatcherHelper.get_exitable_utxos(alice.addr) == []
    assert WatcherHelper.get_utxos(alice.addr) == []
  end

  @tag fixtures: [:in_beam_watcher, :test_server]
  test "hash of returned block does not match hash submitted to the root chain", %{test_server: context} do
    different_hash = <<0::256>>
    block_with_incorrect_hash = %{OMG.Block.hashed_txs_at([], 1000) | hash: different_hash}

    # from now on the child chain server is broken until end of test
    route =
      BadChildChainServer.prepare_route_to_inject_bad_block(
        context,
        block_with_incorrect_hash,
        different_hash
      )

    :sys.replace_state(BlockGetter, fn state ->
      config = state.config
      new_config = %{config | child_chain_url: "http://localhost:#{route.port}"}
      %{state | config: new_config}
    end)

    # checking if both machines and humans learn about the byzantine condition
    assert WatcherHelper.capture_log(fn ->
             {:ok, _txhash} = Eth.submit_block(different_hash, 1, 20_000_000_000)
             IntegrationTest.wait_for_byzantine_events([%Event.InvalidBlock{}.name], @timeout)
           end) =~ inspect({:error, :incorrect_hash})
  end

  @tag fixtures: [:in_beam_watcher, :alice, :test_server]
  test "bad transaction with not existing utxo, detected by interactions with State", %{
    alice: alice,
    test_server: context
  } do
    # preparing block with invalid transaction
    recovered = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 10}])
    block_with_incorrect_transaction = OMG.Block.hashed_txs_at([recovered], 1000)

    # from now on the child chain server is broken until end of test
    route =
      BadChildChainServer.prepare_route_to_inject_bad_block(
        context,
        block_with_incorrect_transaction
      )

    :sys.replace_state(BlockGetter, fn state ->
      config = state.config
      new_config = %{config | child_chain_url: "http://localhost:#{route.port}"}
      %{state | config: new_config}
    end)

    invalid_block_hash = block_with_incorrect_transaction.hash

    # checking if both machines and humans learn about the byzantine condition
    assert WatcherHelper.capture_log(fn ->
             {:ok, _txhash} = Eth.submit_block(invalid_block_hash, 1, 20_000_000_000)
             IntegrationTest.wait_for_byzantine_events([%Event.InvalidBlock{}.name], @timeout)
           end) =~ inspect(:tx_execution)
  end

  @tag fixtures: [:in_beam_watcher, :stable_alice, :mix_based_child_chain, :token, :stable_alice_deposits, :test_server]
  test "transaction which is spending an exiting output before the `sla_margin` causes an invalid_exit event only",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}, test_server: context} do
    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 9}])
    %{"blknum" => exit_blknum} = WatcherHelper.submit(tx)

    # Here we're preparing invalid block
    bad_block_number = 2_000
    bad_tx = OMG.TestHelper.create_recovered([{exit_blknum, 0, 0, alice}], @eth, [{alice, 9}])

    %{hash: bad_block_hash, number: _, transactions: _} =
      bad_block = OMG.Block.hashed_txs_at([bad_tx], bad_block_number)

    # from now on the child chain server is broken until end of test
    route = BadChildChainServer.prepare_route_to_inject_bad_block(context, bad_block)

    :sys.replace_state(BlockGetter, fn state ->
      config = state.config
      new_config = %{config | child_chain_url: "http://localhost:#{route.port}"}
      %{state | config: new_config}
    end)

    IntegrationTest.wait_for_block_fetch(exit_blknum, @timeout)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = WatcherHelper.get_exit_data(exit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => _eth_height}} =
      RootChainHelper.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    # Here we're manually submitting invalid block to the root chain
    # NOTE: this **must** come after `start_exit` is mined (see just above) but still not later than
    #       `sla_margin` after exit start, hence the `config/test.exs` entry for the margin is rather high
    {:ok, _} = Eth.submit_block(bad_block_hash, 2, 1)

    IntegrationTest.wait_for_byzantine_events([%Event.InvalidExit{}.name], @timeout)
  end

  @tag fixtures: [:in_beam_watcher, :stable_alice, :mix_based_child_chain, :token, :stable_alice_deposits, :test_server]
  test "transaction which is spending an exiting output after the `sla_margin` causes an unchallenged_exit event",
       %{stable_alice: alice, stable_alice_deposits: {deposit_blknum, _}, test_server: context} do
    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 9}])
    %{"blknum" => exit_blknum} = WatcherHelper.submit(tx)

    # Here we're preparing invalid block
    bad_tx = OMG.TestHelper.create_recovered([{exit_blknum, 0, 0, alice}], @eth, [{alice, 9}])
    bad_block_number = 2_000

    %{hash: bad_block_hash, number: _, transactions: _} =
      bad_block = OMG.Block.hashed_txs_at([bad_tx], bad_block_number)

    # from now on the child chain server is broken until end of test
    route = BadChildChainServer.prepare_route_to_inject_bad_block(context, bad_block)

    :sys.replace_state(BlockGetter, fn state ->
      config = state.config
      new_config = %{config | child_chain_url: "http://localhost:#{route.port}"}
      %{state | config: new_config}
    end)

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

    exit_processor_sla_margin = Application.fetch_env!(:omg_watcher, :exit_processor_sla_margin)
    DevHelper.wait_for_root_chain_block(eth_height + exit_processor_sla_margin, @timeout)

    # checking if both machines and humans learn about the byzantine condition
    assert WatcherHelper.capture_log(fn ->
             # Here we're manually submitting invalid block to the root chain
             {:ok, _} = Eth.submit_block(bad_block_hash, 2, 1)

             IntegrationTest.wait_for_byzantine_events(
               [%Event.InvalidExit{}.name, %Event.UnchallengedExit{}.name],
               @timeout
             )
           end) =~ inspect(:unchallenged_exit)

    # we should still be able to challenge this "unchallenged exit" - just smoke testing the endpoint, details elsewhere
    WatcherHelper.get_exit_challenge(exit_blknum, 0, 0)
  end

  @tag fixtures: [:in_beam_watcher, :stable_alice, :mix_based_child_chain, :token, :stable_alice_deposits]
  test "block getting halted by block withholding doesn't halt detection of new invalid exits", %{
    stable_alice: alice,
    stable_alice_deposits: {deposit_blknum, _}
  } do
    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 9}])
    %{"blknum" => deposit_blknum} = WatcherHelper.submit(tx)

    tx = OMG.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 8}])
    %{"blknum" => tx_blknum, "txhash" => _tx_hash} = WatcherHelper.submit(tx)

    IntegrationTest.wait_for_block_fetch(tx_blknum, @timeout)

    {_, nonce} = get_next_blknum_nonce(tx_blknum)

    {:ok, _txhash} = Eth.submit_block(<<0::256>>, nonce, 20_000_000_000)

    # checking if both machines and humans learn about the byzantine condition
    assert capture_log(fn ->
             IntegrationTest.wait_for_byzantine_events([%Event.BlockWithholding{}.name], @timeout)
           end) =~ inspect(:withholding)

    %{
      "txbytes" => txbytes,
      "proof" => proof,
      "utxo_pos" => utxo_pos
    } = WatcherHelper.get_exit_data(deposit_blknum, 0, 0)

    {:ok, %{"status" => "0x1", "blockNumber" => _eth_height}} =
      RootChainHelper.start_exit(
        utxo_pos,
        txbytes,
        proof,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    IntegrationTest.wait_for_byzantine_events([%Event.BlockWithholding{}.name, %Event.InvalidExit{}.name], @timeout)
  end

  @tag fixtures: [:in_beam_watcher, :mix_based_child_chain, :test_server, :stable_alice, :stable_alice_deposits]
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
    route =
      BadChildChainServer.prepare_route_to_inject_bad_block(
        context,
        block_overclaiming_fees
      )

    :sys.replace_state(BlockGetter, fn state ->
      config = state.config
      new_config = %{config | child_chain_url: "http://localhost:#{route.port}"}
      %{state | config: new_config}
    end)

    # checking if both machines and humans learn about the byzantine condition
    assert WatcherHelper.capture_log(fn ->
             {:ok, _txhash} = Eth.submit_block(block_overclaiming_fees.hash, 1, 20_000_000_000)
             IntegrationTest.wait_for_byzantine_events([%Event.InvalidBlock{}.name], @timeout)
           end) =~ inspect({:tx_execution, :claimed_and_collected_amounts_mismatch})
  end

  defp get_next_blknum_nonce(blknum) do
    child_block_interval = Application.fetch_env!(:omg_eth, :child_block_interval)
    next_blknum = blknum + child_block_interval
    {next_blknum, trunc(next_blknum / child_block_interval)}
  end
end
