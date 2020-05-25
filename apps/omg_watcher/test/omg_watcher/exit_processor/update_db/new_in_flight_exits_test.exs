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

defmodule OMG.Watcher.ExitProcessor.UpdateDB.NewInFlightExitsTest do
  @moduledoc """
  Unit tests for the NewInFlightExits module.
  Temporary checks the logic with old Core module. Once refactor is all done, should remove those tests.
  """
  use OMG.Watcher.ExitProcessor.Case, async: true

  alias OMG.State.Transaction
  alias OMG.TestHelper, as: OMGTestHelper
  alias OMG.Utxo
  alias OMG.Utxo.Position
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.TestHelper, as: EPTestHelper
  alias OMG.Watcher.ExitProcessor.UpdateDB.NewInflightExits

  require Utxo

  @eth OMG.Eth.zero_address()
  @not_eth <<1::size(160)>>
  @late_blknum 10_000
  @utxo_pos1 Utxo.position(2, 0, 0)
  @utxo_pos2 Utxo.position(@late_blknum - 1_000, 0, 1)

  describe "get_db_updates/2" do
    test "returns error as unexpected events when length of inputs mismatches" do
      assert {:error, :unexpected_events} == NewInflightExits.get_db_updates([], [:anything])
      assert {:error, :unexpected_events} == NewInflightExits.get_db_updates([:anything], [])
    end

    test "returns empty list when inputs are empty" do
      assert {:ok, []} = NewInflightExits.get_db_updates([], [])
    end

    test "returns the expected db_updates given single events", %{processor_empty: empty} do
      [alice, bob, carol] = Enum.map(1..3, fn _ -> OMGTestHelper.generate_entity() end)

      youngest_blknum = 10

      tx =
        OMGTestHelper.create_recovered([{youngest_blknum, 0, 0, alice}, {youngest_blknum - 1, 2, 1, carol}], [
          {alice, @eth, 1},
          {carol, @eth, 2}
        ])

      event = EPTestHelper.ife_event(tx, eth_height: 4)

      active_ife_status = {_, timestamp, _, _, _, _, _} = EPTestHelper.active_ife_status()
      ife_exit_id = 1
      status = {active_ife_status, ife_exit_id}

      expected_db_update = {
        :put,
        :in_flight_exit_info,
        {
          Transaction.raw_txhash(tx),
          %{
            contract_id: <<ife_exit_id::192>>,
            eth_height: event.eth_height,
            exit_map: %{},
            input_txs: event.call_data.input_txs,
            input_utxos_pos: Enum.map(event.call_data.input_utxos_pos, fn pos -> Position.decode!(pos) end),
            is_active: true,
            is_canonical: true,
            oldest_competitor: nil,
            relevant_from_blknum: youngest_blknum,
            timestamp: timestamp,
            tx: %{
              raw_tx: Map.from_struct(tx.signed_tx.raw_tx),
              sigs: tx.signed_tx.sigs
            },
            tx_pos: nil
          }
        }
      }

      {:ok, db_updates} = NewInflightExits.get_db_updates([event], [status])
      assert [expected_db_update] == db_updates

      # TODO: remove this once refactor is done.
      {_state, ^db_updates} = Core.new_in_flight_exits(empty, [event], [status])
    end

    test "returns the expected db_updates given multiple events", %{processor_empty: empty} do
      [alice, bob, carol] = Enum.map(1..3, fn _ -> OMGTestHelper.generate_entity() end)

      [youngest_blknum_1, youngest_blknum_2] = [10, 15]

      tx1 =
        OMGTestHelper.create_recovered([{youngest_blknum_1, 0, 0, alice}, {youngest_blknum_1 - 1, 2, 1, carol}], [
          {alice, @eth, 1},
          {carol, @eth, 2}
        ])

      tx2 =
        OMGTestHelper.create_recovered([{youngest_blknum_2, 1, 0, alice}, {youngest_blknum_2 - 1, 2, 1, carol}], [
          {alice, @not_eth, 1},
          {carol, @not_eth, 2}
        ])

      events =
        [event1, event2] =
        [tx1, tx2]
        |> Enum.zip([2, 4])
        |> Enum.map(fn {tx, eth_height} -> EPTestHelper.ife_event(tx, eth_height: eth_height) end)

      active_ife_status = {_, timestamp, _, _, _, _, _} = EPTestHelper.active_ife_status()
      [ife_exit_id_1, ife_exit_id_2] = [1, 2]
      statuses = [{active_ife_status, ife_exit_id_1}, {active_ife_status, ife_exit_id_2}]

      expected_db_update1 = {
        :put,
        :in_flight_exit_info,
        {
          Transaction.raw_txhash(tx1),
          %{
            contract_id: <<ife_exit_id_1::192>>,
            eth_height: event1.eth_height,
            exit_map: %{},
            input_txs: event1.call_data.input_txs,
            input_utxos_pos: Enum.map(event1.call_data.input_utxos_pos, fn pos -> Position.decode!(pos) end),
            is_active: true,
            is_canonical: true,
            oldest_competitor: nil,
            relevant_from_blknum: youngest_blknum_1,
            timestamp: timestamp,
            tx: %{
              raw_tx: Map.from_struct(tx1.signed_tx.raw_tx),
              sigs: tx1.signed_tx.sigs
            },
            tx_pos: nil
          }
        }
      }

      expected_db_update2 = {
        :put,
        :in_flight_exit_info,
        {
          Transaction.raw_txhash(tx2),
          %{
            contract_id: <<ife_exit_id_2::192>>,
            eth_height: event2.eth_height,
            exit_map: %{},
            input_txs: event2.call_data.input_txs,
            input_utxos_pos: Enum.map(event2.call_data.input_utxos_pos, fn pos -> Position.decode!(pos) end),
            is_active: true,
            is_canonical: true,
            oldest_competitor: nil,
            relevant_from_blknum: youngest_blknum_2,
            timestamp: timestamp,
            tx: %{
              raw_tx: Map.from_struct(tx2.signed_tx.raw_tx),
              sigs: tx2.signed_tx.sigs
            },
            tx_pos: nil
          }
        }
      }

      {:ok, db_updates} = NewInflightExits.get_db_updates(events, statuses)
      assert [expected_db_update1, expected_db_update2] == db_updates

      # TODO: remove this once refactor is done.
      # Somehow the old implementation is flaky on the ordering of the db_update data
      {_state, old_db_updates} = Core.new_in_flight_exits(empty, events, statuses)
      assert Enum.sort(old_db_updates) == Enum.sort(db_updates)
    end
  end
end
