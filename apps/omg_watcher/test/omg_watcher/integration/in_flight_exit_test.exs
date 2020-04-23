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

defmodule OMG.Watcher.Integration.InFlightExitTest do
  @moduledoc """
  This needs to go away real soon.
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.ChildChain.Integration.Fixtures
  use Plug.Test

  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.EthereumEventAggregator
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias Support.DevHelper
  alias Support.RootChainHelper
  alias Support.WatcherHelper

  require Utxo

  @timeout 40_000
  @eth OMG.Eth.zero_address()
  @hex_eth "0x0000000000000000000000000000000000000000"

  @moduletag :integration
  @moduletag :watcher
  # bumping the timeout to three minutes for the tests here, as they do a lot of transactions to Ethereum to test
  @moduletag timeout: 180_000

  @tag fixtures: [:in_beam_watcher, :alice, :bob, :mix_based_child_chain, :token, :alice_deposits]
  test "in-flight exit competitor is detected by watcher and proven with position immediately",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    # tx1 is submitted then in-flight-exited
    # tx2 is in-flight-exited
    tx1 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 4}])
    tx2 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{bob, 9}])

    ife1 = tx1 |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()
    ife2 = tx2 |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()

    assert %{"blknum" => blknum} = tx1 |> Transaction.Signed.encode() |> WatcherHelper.submit()

    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    raw_tx2_bytes = Transaction.raw_txbytes(tx2)

    {:ok, %{"status" => "0x1", "blockNumber" => _}} = exit_in_flight(ife1, alice)
    {:ok, %{"status" => "0x1", "blockNumber" => ife_eth_height}} = exit_in_flight(ife2, alice)
    # sanity check in-flight exit has started on root chain, wait for finality
    assert {:ok, [_, _]} = EthereumEventAggregator.in_flight_exit_started(0, ife_eth_height)

    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)
    DevHelper.wait_for_root_chain_block(ife_eth_height + exit_finality_margin + 1)

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
           } = WatcherHelper.success?("/status.get")

    # Check if IFE is recognized as IFE by watcher (kept separate from the above for readability)
    assert %{"in_flight_exits" => [%{}, %{}]} = WatcherHelper.success?("/status.get")

    ###
    # CANONICITY GAME
    ###

    assert %{"competing_tx_pos" => id, "competing_proof" => proof} =
             get_competitor_response = WatcherHelper.get_in_flight_exit_competitors(raw_tx2_bytes)

    assert id > 0
    assert proof != ""

    {:ok, %{"status" => "0x1", "blockNumber" => challenge_eth_height}} =
      RootChainHelper.challenge_in_flight_exit_not_canonical(
        get_competitor_response["input_tx"],
        get_competitor_response["input_utxo_pos"],
        get_competitor_response["in_flight_txbytes"],
        get_competitor_response["in_flight_input_index"],
        get_competitor_response["competing_txbytes"],
        get_competitor_response["competing_input_index"],
        get_competitor_response["competing_tx_pos"],
        get_competitor_response["competing_proof"],
        get_competitor_response["competing_sig"],
        alice.addr
      )
      |> DevHelper.transact_sync!()

    DevHelper.wait_for_root_chain_block(challenge_eth_height + exit_finality_margin + 1)

    # vanishing of `non_canonical_ife` event
    assert %{"byzantine_events" => [%{"event" => "piggyback_available"}]} = WatcherHelper.success?("/status.get")
  end

  @tag fixtures: [:in_beam_watcher, :alice, :bob, :mix_based_child_chain, :token, :alice_deposits]
  test "invalid in-flight exit challenge is detected by watcher, because it contains no position",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    # tx1 is submitted then in-flight-exited
    # tx2 is in-flight-exited, it will be _invalidly_ used to challenge tx1!
    tx1 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 4}])
    tx2 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{bob, 9}])

    ife1 = tx1 |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()
    ife2 = tx2 |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()

    assert %{
             "blknum" => blknum,
             "txindex" => 0,
             "txhash" => <<_::256>>
           } = tx1 |> Transaction.Signed.encode() |> WatcherHelper.submit()

    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    raw_tx1_bytes = Transaction.raw_txbytes(tx1)
    raw_tx2_bytes = Transaction.raw_txbytes(tx2)

    {:ok, %{"status" => "0x1", "blockNumber" => _}} = exit_in_flight(ife1, alice)
    {:ok, %{"status" => "0x1", "blockNumber" => ife_eth_height}} = exit_in_flight(ife2, alice)
    # sanity check in-flight exit has started on root chain, wait for finality
    assert {:ok, [_, _]} = EthereumEventAggregator.in_flight_exit_started(0, ife_eth_height)
    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)
    DevHelper.wait_for_root_chain_block(ife_eth_height + exit_finality_margin + 1)

    # EVENTS DETECTION (tested in the other test, skipping)
    # Check if IFE is recognized (tested in the other test, skipping)

    ###
    # CANONICITY GAME
    ###

    # we're unable to get the invalid challenge using `in_flight_exit.get_competitor`!
    # ...so we need to stich it together from some pieces we have:
    %{sigs: [competing_sig | _]} = tx2
    competing_tx_input_txbytes = Transaction.Payment.new([], [{alice.addr, @eth, 10}]) |> Transaction.raw_txbytes()
    competing_tx_input_utxo_pos = Utxo.position(deposit_blknum, 0, 0) |> Utxo.Position.encode()

    {:ok, %{"status" => "0x1", "blockNumber" => challenge_eth_height}} =
      RootChainHelper.challenge_in_flight_exit_not_canonical(
        competing_tx_input_txbytes,
        competing_tx_input_utxo_pos,
        raw_tx1_bytes,
        0,
        raw_tx2_bytes,
        0,
        0,
        "",
        competing_sig,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    DevHelper.wait_for_root_chain_block(challenge_eth_height + exit_finality_margin + 1)

    # existence of `invalid_ife_challenge` event
    assert %{
             "byzantine_events" => [
               # this is the tx2's non-canonical-ife which we leave as is
               %{"event" => "non_canonical_ife"},
               %{"event" => "invalid_ife_challenge"},
               %{"event" => "piggyback_available"}
             ]
           } = WatcherHelper.success?("/status.get")

    # now included IFE transaction tx1 is challenged and non-canonical, let's respond
    get_prove_canonical_response = WatcherHelper.get_prove_canonical(raw_tx1_bytes)

    {:ok, %{"status" => "0x1", "blockNumber" => response_eth_height}} =
      RootChainHelper.respond_to_non_canonical_challenge(
        get_prove_canonical_response["in_flight_txbytes"],
        get_prove_canonical_response["in_flight_tx_pos"],
        get_prove_canonical_response["in_flight_proof"],
        alice.addr
      )
      |> DevHelper.transact_sync!()

    DevHelper.wait_for_root_chain_block(response_eth_height + exit_finality_margin + 1)

    # dissapearing of `invalid_ife_challenge` event
    assert %{"byzantine_events" => [%{"event" => "non_canonical_ife"}, %{"event" => "piggyback_available"}]} =
             WatcherHelper.success?("/status.get")
  end

  @tag fixtures: [:in_beam_watcher, :alice, :bob, :mix_based_child_chain, :token, :alice_deposits]
  test "honest and cooperating users exit in-flight transaction",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    DevHelper.import_unlock_fund(bob)

    tx = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 4}, {bob, 5}])
    ife1 = tx |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()

    %{"blknum" => blknum} = tx |> Transaction.Signed.encode() |> WatcherHelper.submit()
    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    _ = exit_in_flight_and_wait_for_ife(ife1, alice)

    assert %{"in_flight_exits" => [%{}]} = WatcherHelper.success?("/status.get")

    _ = piggyback_and_process_exits(tx, 1, :output, bob)

    assert %{"in_flight_exits" => [], "byzantine_events" => []} = WatcherHelper.success?("/status.get")
  end

  # NOTE: if https://github.com/omisego/elixir-omg/issues/994 is taken care of, this behavior will change, see comments
  #       therein.
  @tag fixtures: [:in_beam_watcher, :alice, :bob, :mix_based_child_chain, :token, :alice_deposits]
  test "finalization of output from non-included IFE tx - all is good",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    DevHelper.import_unlock_fund(bob)

    tx = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {bob, 5}])
    _ = exit_in_flight_and_wait_for_ife(tx, alice)
    piggyback_and_process_exits(tx, 1, :output, bob)

    assert %{"in_flight_exits" => [], "byzantine_events" => []} = WatcherHelper.success?("/status.get")
  end

  @tag fixtures: [:in_beam_watcher, :alice, :bob, :mix_based_child_chain, :token, :alice_deposits]
  test "finalization of utxo double-spent in state leaves in-flight exit active and invalid; warns",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    DevHelper.import_unlock_fund(bob)

    tx = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {bob, 4}])
    ife1 = tx |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()

    %{"blknum" => blknum} = tx |> Transaction.Signed.encode() |> WatcherHelper.submit()
    invalidating_tx = OMG.TestHelper.create_encoded([{blknum, 0, 0, alice}], @eth, [{alice, 4}])
    %{"blknum" => invalidating_blknum} = WatcherHelper.submit(invalidating_tx)
    IntegrationTest.wait_for_block_fetch(invalidating_blknum, @timeout)

    _ = exit_in_flight_and_wait_for_ife(ife1, alice)

    # checking if both machines and humans learn about the byzantine condition
    assert WatcherHelper.capture_log(fn ->
             _ = piggyback_and_process_exits(tx, 0, :output, alice)
           end) =~ "Invalid in-flight exit finalization"

    assert %{"in_flight_exits" => [_], "byzantine_events" => byzantine_events} = WatcherHelper.success?("/status.get")
    assert [%{"event" => "invalid_piggyback"}] = Enum.filter(byzantine_events, &(&1["event"] != "piggyback_available"))
  end

  @tag fixtures: [:in_beam_watcher, :alice, :bob, :mix_based_child_chain, :token, :alice_deposits]
  test "invalid piggyback causes unchallenged exit byzantine event when sla margin period passes",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    DevHelper.import_unlock_fund(bob)

    tx = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {bob, 4}])
    ife1 = tx |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()

    %{"blknum" => blknum} = tx |> Transaction.Signed.encode() |> WatcherHelper.submit()
    invalidating_tx = OMG.TestHelper.create_encoded([{blknum, 0, 0, alice}], @eth, [{alice, 4}])
    %{"blknum" => invalidating_blknum} = WatcherHelper.submit(invalidating_tx)
    IntegrationTest.wait_for_block_fetch(invalidating_blknum, @timeout)

    {:ok, eth_height} = exit_in_flight_and_wait_for_ife(ife1, alice)

    _ = piggyback_and_process_exits(tx, 0, :output, alice)

    assert %{"in_flight_exits" => [_], "byzantine_events" => byzantine_events} = WatcherHelper.success?("/status.get")
    assert [%{"event" => "invalid_piggyback"}] = Enum.filter(byzantine_events, &(&1["event"] != "piggyback_available"))

    exit_processor_sla_margin = Application.fetch_env!(:omg_watcher, :exit_processor_sla_margin)
    DevHelper.wait_for_root_chain_block(eth_height + exit_processor_sla_margin, @timeout)

    IntegrationTest.wait_for_byzantine_event(
      %OMG.Watcher.Event.UnchallengedExit{}.name,
      @timeout
    )
  end

  @tag fixtures: [:in_beam_watcher, :alice, :bob, :mix_based_child_chain, :token, :alice_deposits]
  test "non canonical ife causes unchallenged exit byzantine event when sla margin period passes",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    # tx1 is submitted then in-flight-exited
    # tx2 is in-flight-exited
    tx1 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 4}])
    tx2 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{bob, 9}])

    ife1 = tx1 |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()
    ife2 = tx2 |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()

    assert %{"blknum" => blknum} = tx1 |> Transaction.Signed.encode() |> WatcherHelper.submit()

    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    raw_tx2_bytes = Transaction.raw_txbytes(tx2)

    {:ok, %{"status" => "0x1", "blockNumber" => _}} = exit_in_flight(ife1, alice)
    {:ok, %{"status" => "0x1", "blockNumber" => ife_eth_height}} = exit_in_flight(ife2, alice)

    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)

    ife_noticed_eth_height = ife_eth_height + exit_finality_margin + 1
    DevHelper.wait_for_root_chain_block(ife_noticed_eth_height)

    assert %{
             "byzantine_events" => [
               # only a single non_canonical event, since on of the IFE tx is included!
               %{"event" => "non_canonical_ife"},
               %{"event" => "piggyback_available"}
             ]
           } = WatcherHelper.success?("/status.get")

    exit_processor_sla_margin = Application.fetch_env!(:omg_watcher, :exit_processor_sla_margin)
    DevHelper.wait_for_root_chain_block(ife_noticed_eth_height + exit_processor_sla_margin, @timeout)

    IntegrationTest.wait_for_byzantine_event(
      %OMG.Watcher.Event.UnchallengedExit{}.name,
      @timeout
    )
  end

  @tag fixtures: [:in_beam_watcher, :alice, :bob, :mix_based_child_chain, :token, :alice_deposits]
  test "invalid ife challenge causes unchallenged exit byzantine event when sla margin period passes",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    # tx1 is submitted then in-flight-exited
    # tx2 is in-flight-exited, it will be _invalidly_ used to challenge tx1!
    tx1 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 4}])
    tx2 = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{bob, 9}])

    ife1 = tx1 |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()
    ife2 = tx2 |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()

    assert %{
             "blknum" => blknum,
             "txindex" => 0,
             "txhash" => <<_::256>>
           } = tx1 |> Transaction.Signed.encode() |> WatcherHelper.submit()

    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    raw_tx1_bytes = Transaction.raw_txbytes(tx1)
    raw_tx2_bytes = Transaction.raw_txbytes(tx2)

    {:ok, %{"status" => "0x1", "blockNumber" => _}} = exit_in_flight(ife1, alice)
    {:ok, %{"status" => "0x1", "blockNumber" => ife_eth_height}} = exit_in_flight(ife2, alice)

    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)
    DevHelper.wait_for_root_chain_block(ife_eth_height + exit_finality_margin + 1)

    %{sigs: [competing_sig | _]} = tx2
    competing_tx_input_txbytes = Transaction.Payment.new([], [{alice.addr, @eth, 10}]) |> Transaction.raw_txbytes()
    competing_tx_input_utxo_pos = Utxo.position(deposit_blknum, 0, 0) |> Utxo.Position.encode()

    {:ok, %{"status" => "0x1", "blockNumber" => challenge_eth_height}} =
      RootChainHelper.challenge_in_flight_exit_not_canonical(
        competing_tx_input_txbytes,
        competing_tx_input_utxo_pos,
        raw_tx1_bytes,
        0,
        raw_tx2_bytes,
        0,
        0,
        "",
        competing_sig,
        alice.addr
      )
      |> DevHelper.transact_sync!()

    challenge_noticed_eth_height = challenge_eth_height + exit_finality_margin + 1
    DevHelper.wait_for_root_chain_block(challenge_noticed_eth_height)

    # existence of `invalid_ife_challenge` event
    assert %{
             "byzantine_events" => [
               # this is the tx2's non-canonical-ife which we leave as is
               %{"event" => "non_canonical_ife"},
               %{"event" => "invalid_ife_challenge"},
               %{"event" => "piggyback_available"}
             ]
           } = WatcherHelper.success?("/status.get")

    exit_processor_sla_margin = Application.fetch_env!(:omg_watcher, :exit_processor_sla_margin)
    DevHelper.wait_for_root_chain_block(challenge_noticed_eth_height + exit_processor_sla_margin, @timeout)

    IntegrationTest.wait_for_byzantine_event(
      %OMG.Watcher.Event.UnchallengedExit{}.name,
      @timeout
    )
  end

  defp exit_in_flight(%Transaction.Signed{} = tx, exiting_user) do
    get_in_flight_exit_response = tx |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()
    exit_in_flight(get_in_flight_exit_response, exiting_user)
  end

  defp exit_in_flight(get_in_flight_exit_response, exiting_user) do
    RootChainHelper.in_flight_exit(
      get_in_flight_exit_response["in_flight_tx"],
      get_in_flight_exit_response["input_txs"],
      get_in_flight_exit_response["input_utxos_pos"],
      get_in_flight_exit_response["input_txs_inclusion_proofs"],
      get_in_flight_exit_response["in_flight_tx_sigs"],
      exiting_user.addr
    )
    |> DevHelper.transact_sync!()
  end

  defp exit_in_flight_and_wait_for_ife(tx, exiting_user) do
    {:ok, %{"status" => "0x1", "blockNumber" => eth_height}} = exit_in_flight(tx, exiting_user)
    exit_finality_margin = Application.fetch_env!(:omg_watcher, :exit_finality_margin)
    DevHelper.wait_for_root_chain_block(eth_height + exit_finality_margin + 1)
  end

  defp piggyback_and_process_exits(%Transaction.Signed{raw_tx: raw_tx}, index, piggyback_type, output_owner) do
    raw_tx_bytes = Transaction.raw_txbytes(raw_tx)

    {:ok, %{"status" => "0x1"}} =
      case piggyback_type do
        :input ->
          RootChainHelper.piggyback_in_flight_exit_on_input(raw_tx_bytes, index, output_owner.addr)

        :output ->
          RootChainHelper.piggyback_in_flight_exit_on_output(raw_tx_bytes, index, output_owner.addr)
      end
      |> DevHelper.transact_sync!()

    :ok = IntegrationTest.process_exits(1, @hex_eth, output_owner)
  end
end
