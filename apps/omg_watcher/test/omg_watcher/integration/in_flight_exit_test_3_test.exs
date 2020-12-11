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

defmodule OMG.Watcher.Integration.InFlightExit3Test do
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
  @eth OMG.Eth.zero_address()
  @hex_eth "0x0000000000000000000000000000000000000000"

  @moduletag :mix_based_child_chain
  # bumping the timeout to three minutes for the tests here, as they do a lot of transactions to Ethereum to test
  @moduletag timeout: 180_000

  @tag fixtures: [:in_beam_watcher, :alice, :bob, :token, :alice_deposits]
  test "honest and cooperating users exit in-flight transaction",
       %{alice: alice, bob: bob, alice_deposits: {deposit_blknum, _}} do
    # we need to recognized the deposit on the childchain first
    Process.sleep(12_000)
    DevHelper.import_unlock_fund(bob)

    tx = OMG.TestHelper.create_signed([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 4}, {bob, 5}])
    ife1 = tx |> Transaction.Signed.encode() |> WatcherHelper.get_in_flight_exit()

    %{"blknum" => blknum} = tx |> Transaction.Signed.encode() |> WatcherHelper.submit()
    IntegrationTest.wait_for_block_fetch(blknum, @timeout)

    {:ok, %{"status" => "0x1", "blockNumber" => _eth_height}} = exit_in_flight(ife1, alice)

    [ife] = wait_for_not_empty_in_flight_exits()
    assert is_map(ife)
    _ = piggyback_and_process_exits(tx, 1, :output, bob)
    expected_events = []
    :ok = wait_for(expected_events)
    :ok = wait_for_empty_in_flight_exits()
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

  defp wait_for_not_empty_in_flight_exits() do
    Enum.reduce_while(1..1000, 0, fn x, acc ->
      ife = "/status.get" |> WatcherHelper.success?() |> Map.get("in_flight_exits")

      case ife do
        [] ->
          Process.sleep(10)

          {:cont, acc + x}

        ife ->
          {:halt, ife}
      end
    end)
  end

  defp wait_for_empty_in_flight_exits() do
    Enum.reduce_while(1..1000, 0, fn x, acc ->
      ife = "/status.get" |> WatcherHelper.success?() |> Map.get("in_flight_exits")

      case ife do
        [] ->
          {:halt, :ok}

        _ ->
          Process.sleep(10)

          {:cont, acc + x}
      end
    end)
  end
end
