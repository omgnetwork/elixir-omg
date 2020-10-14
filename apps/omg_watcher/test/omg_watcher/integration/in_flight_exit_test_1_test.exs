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

defmodule OMG.Watcher.Integration.InFlightExit1Test do
  @moduledoc """
  This needs to go away real soon.
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use Plug.Test
  use OMG.Watcher.Integration.Fixtures

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

  @moduletag :mix_based_child_chain
  # bumping the timeout to three minutes for the tests here, as they do a lot of transactions to Ethereum to test
  @moduletag timeout: 180_000

  @tag fixtures: [:in_beam_watcher, :alice, :bob, :token, :alice_deposits]
  test "invalid in-flight exit challenge is detected by watcher, because it contains no position",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    # we need to recognized the deposit on the childchain first
    Process.sleep(12_000)
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
    DevHelper.wait_for_root_chain_block(ife_eth_height + exit_finality_margin)

    ###
    # CANONICITY GAME
    ###

    # we're unable to get the invalid challenge using `in_flight_exit.get_competitor`!
    # ...so we need to stich it together from some pieces we have:
    %{sigs: [competing_sig | _]} = tx2
    competing_tx_input_txbytes = [] |> Transaction.Payment.new([{alice.addr, @eth, 10}]) |> Transaction.raw_txbytes()
    competing_tx_input_utxo_pos = Utxo.Position.encode(Utxo.position(deposit_blknum, 0, 0))

    {:ok, %{"status" => "0x1", "blockNumber" => _challenge_eth_height}} =
      competing_tx_input_txbytes
      |> RootChainHelper.challenge_in_flight_exit_not_canonical(
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

    # existence of `invalid_ife_challenge` event
    # vanishing of `non_canonical_ife` event
    expected_events = [
      # this is the tx2's non-canonical-ife which we leave as is
      %{"event" => "non_canonical_ife"},
      %{"event" => "invalid_ife_challenge"},
      %{"event" => "piggyback_available"}
    ]

    :ok = wait_for(expected_events)

    # now included IFE transaction tx1 is challenged and non-canonical, let's respond
    get_prove_canonical_response = WatcherHelper.get_prove_canonical(raw_tx1_bytes)

    {:ok, %{"status" => "0x1", "blockNumber" => _response_eth_height}} =
      get_prove_canonical_response["in_flight_txbytes"]
      |> RootChainHelper.respond_to_non_canonical_challenge(
        get_prove_canonical_response["in_flight_tx_pos"],
        get_prove_canonical_response["in_flight_proof"],
        alice.addr
      )
      |> DevHelper.transact_sync!()

    expected_events = [
      # this is the tx2's non-canonical-ife which we leave as is
      %{"event" => "non_canonical_ife"},
      %{"event" => "piggyback_available"}
    ]

    :ok = wait_for(expected_events)
  end

  defp exit_in_flight(%Transaction.Signed{} = tx, exiting_user) do
    get_in_flight_exit_response = tx |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()
    exit_in_flight(get_in_flight_exit_response, exiting_user)
  end

  defp exit_in_flight(get_in_flight_exit_response, exiting_user) do
    get_in_flight_exit_response["in_flight_tx"]
    |> RootChainHelper.in_flight_exit(
      get_in_flight_exit_response["input_txs"],
      get_in_flight_exit_response["input_utxos_pos"],
      get_in_flight_exit_response["input_txs_inclusion_proofs"],
      get_in_flight_exit_response["in_flight_tx_sigs"],
      exiting_user.addr
    )
    |> DevHelper.transact_sync!()
  end

  defp wait_for(expected_events) do
    Enum.reduce_while(1..1000, 0, fn x, acc ->
      events =
        "/status.get" |> WatcherHelper.success?() |> Map.get("byzantine_events") |> Enum.map(&Map.take(&1, ["event"]))

      case events do
        ^expected_events ->
          {:halt, :ok}

        _ ->
          Process.sleep(10)

          {:cont, acc + x}
      end
    end)
  end
end
