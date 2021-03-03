# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Watcher.Integration.InFlightExit2Test do
  @moduledoc """
  This needs to go away real soon.
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Watcher.Fixtures
  use Plug.Test
  use OMG.Watcher.Integration.Fixtures

  alias OMG.Watcher.State.Transaction
  alias OMG.Watcher.Utxo
  alias OMG.Watcher.EthereumEventAggregator
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias Support.DevHelper
  alias Support.RootChainHelper
  alias Support.WatcherHelper
  alias OMG.Watcher.TestHelper

  require Utxo

  @timeout 40_000
  @eth <<0::160>>

  @moduletag :mix_based_child_chain
  # bumping the timeout to three minutes for the tests here, as they do a lot of transactions to Ethereum to test
  @moduletag timeout: 180_000

  @tag fixtures: [:in_beam_watcher, :alice, :bob, :token, :alice_deposits]
  test "in-flight exit competitor is detected by watcher and proven with position immediately",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    # we need to recognized the deposit on the childchain first
    Process.sleep(12_000)
    # tx1 is submitted then in-flight-exited
    # tx2 is in-flight-exited
    tx1 = TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 5}, {alice, 4}])
    tx2 = TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{bob, 9}])

    ife1 = tx1 |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()
    ife2 = tx2 |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()

    assert %{"blknum" => blknum} = tx1 |> Transaction.Signed.encode() |> WatcherHelper.submit()

    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    raw_tx2_bytes = Transaction.raw_txbytes(tx2)

    {:ok, %{"status" => "0x1", "blockNumber" => _}} = exit_in_flight(ife1, alice)
    {:ok, %{"status" => "0x1", "blockNumber" => ife_eth_height}} = exit_in_flight(ife2, alice)
    # sanity check in-flight exit has started on root chain, wait for finality
    assert {:ok, [_, _]} = EthereumEventAggregator.in_flight_exit_started(0, ife_eth_height)

    ###
    # EVENTS DETECTION
    ###

    # existence of competitors detected by checking if `non_canonical_ife` events exists
    # Also, there should be piggybacks on input/output available

    expected_events = [
      # only a single non_canonical event, since on of the IFE tx is included!
      %{"event" => "non_canonical_ife"},
      %{"event" => "piggyback_available"}
    ]

    :ok = wait_for(expected_events)

    # Check if IFE is recognized as IFE by watcher (kept separate from the above for readability)
    assert %{"in_flight_exits" => [%{}, %{}]} = WatcherHelper.success?("/status.get")

    ###
    # CANONICITY GAME
    ###

    assert %{"competing_tx_pos" => id, "competing_proof" => proof} =
             get_competitor_response = WatcherHelper.get_in_flight_exit_competitors(raw_tx2_bytes)

    assert id > 0
    assert proof != ""

    {:ok, %{"status" => "0x1", "blockNumber" => _challenge_eth_height}} =
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

    # vanishing of `non_canonical_ife` event
    expected_events = [%{"event" => "piggyback_available"}]

    :ok = wait_for(expected_events)
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
