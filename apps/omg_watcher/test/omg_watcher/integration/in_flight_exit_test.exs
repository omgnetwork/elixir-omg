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

defmodule OMG.Watcher.Integration.InFlightExitTest do
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
  alias OMG.Watcher.Integration.TestHelper, as: IntegrationTest
  alias Support.DevHelper
  alias Support.RootChainHelper
  alias Support.WatcherHelper

  require Utxo

  @timeout 40_000
  @eth <<0::160>>
  @hex_eth "0x0000000000000000000000000000000000000000"

  @moduletag :mix_based_child_chain
  # bumping the timeout to three minutes for the tests here, as they do a lot of transactions to Ethereum to test
  @moduletag timeout: 240_000

  @tag fixtures: [:in_beam_watcher, :alice, :bob, :token, :alice_deposits]
  test "finalization of utxo double-spent in state leaves in-flight exit active and invalid; warns",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    Process.sleep(12_000)
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
             # :output type
             _ = piggyback_and_process_exits(tx, 0, alice)
           end) =~ "Invalid in-flight exit finalization"

    assert %{"in_flight_exits" => [_], "byzantine_events" => byzantine_events} = WatcherHelper.success?("/status.get")
    # invalid piggyback is past sla margin, unchallenged_piggyback event is emitted
    assert [%{"event" => "unchallenged_piggyback"}, %{"event" => "invalid_piggyback"}] =
             Enum.filter(byzantine_events, &(&1["event"] != "piggyback_available"))
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

  defp piggyback_and_process_exits(%Transaction.Signed{raw_tx: raw_tx}, index, output_owner) do
    raw_tx_bytes = Transaction.raw_txbytes(raw_tx)

    {:ok, %{"status" => "0x1"}} =
      raw_tx_bytes
      |> RootChainHelper.piggyback_in_flight_exit_on_output(index, output_owner.addr)
      |> DevHelper.transact_sync!()

    :ok = IntegrationTest.process_exits(1, @hex_eth, output_owner)
  end
end
