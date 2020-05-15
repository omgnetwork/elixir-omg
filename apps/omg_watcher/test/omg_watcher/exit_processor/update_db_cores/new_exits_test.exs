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

defmodule OMG.Watcher.ExitProcessor.UpdateDB.NewExitsTest do
  use ExUnit.Case, async: true

  alias OMG.Utxo
  alias OMG.Utxo.Position
  alias OMG.Watcher.ExitProcessor.UpdateDB.NewExits
  alias OMG.Watcher.ExitProcessor.TestHelper, as: EPTestHelper
  alias OMG.TestHelper, as: OMGTestHelper

  require Utxo

  @eth OMG.Eth.zero_address()
  @late_blknum 10_000
  @utxo_pos1 Utxo.position(2, 0, 0)
  @utxo_pos2 Utxo.position(@late_blknum - 1_000, 0, 1)

  describe "get_db_update/2" do
    test "returns error as unexpected events when length of inputs mismatches" do
      assert {:error, :unexpected_events} == NewExits.get_db_update([], [:anything])
      assert {:error, :unexpected_events} == NewExits.get_db_update([:anything], [])
    end

    test "returns empty list when inputs are empty" do
      assert {:ok, []} = NewExits.get_db_update([], [])
    end

    test "returns the expected db_updates given single event" do
      [alice, bob] = Enum.map(1..2, fn _ -> OMGTestHelper.generate_entity() end)

      test_amount = 10
      standard_exit_tx = OMGTestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, test_amount}])
      {event, status} = EPTestHelper.se_event_status(standard_exit_tx, @utxo_pos1)

      expected_db_update = {
        :put,
        :exit_info,
        {
          event.call_data.utxo_pos |> Position.decode!() |> Tuple.delete_at(0),
          %{
            amount: test_amount,
            block_timestamp: event.block_timestamp,
            currency: @eth,
            eth_height: event.eth_height,
            exit_id: event.exit_id,
            exiting_txbytes: event.call_data.output_tx,
            is_active: true,
            owner: event.owner,
            root_chain_txhash: event.root_chain_txhash,
            scheduled_finalization_time: event.scheduled_finalization_time
          }
        }
      }

      {:ok, db_updates} = NewExits.get_db_update([event], [status])
      assert [expected_db_update] == db_updates
    end

    test "returns the expected db_updates given multiple events" do
      [alice, bob] = Enum.map(1..2, fn _ -> OMGTestHelper.generate_entity() end)

      test_amount = 10
      standard_exit_tx1 = OMGTestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, test_amount}])

      standard_exit_tx2 =
        OMGTestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, test_amount}, {bob, test_amount}])

      {event1, status1} = EPTestHelper.se_event_status(standard_exit_tx1, @utxo_pos1)
      {event2, status2} = EPTestHelper.se_event_status(standard_exit_tx2, @utxo_pos2)
      events = [event1, event2]
      statuses = [status1, status2]

      expected_db_update_1 = {
        :put,
        :exit_info,
        {
          event1.call_data.utxo_pos |> Position.decode!() |> Tuple.delete_at(0),
          %{
            amount: test_amount,
            block_timestamp: event1.block_timestamp,
            currency: @eth,
            eth_height: event1.eth_height,
            exit_id: event1.exit_id,
            exiting_txbytes: event1.call_data.output_tx,
            is_active: true,
            owner: event1.owner,
            root_chain_txhash: event1.root_chain_txhash,
            scheduled_finalization_time: event1.scheduled_finalization_time
          }
        }
      }

      expected_db_update_2 = {
        :put,
        :exit_info,
        {
          event2.call_data.utxo_pos |> Position.decode!() |> Tuple.delete_at(0),
          %{
            amount: test_amount,
            block_timestamp: event2.block_timestamp,
            currency: @eth,
            eth_height: event2.eth_height,
            exit_id: event2.exit_id,
            exiting_txbytes: event2.call_data.output_tx,
            is_active: true,
            owner: event2.owner,
            root_chain_txhash: event2.root_chain_txhash,
            scheduled_finalization_time: event2.scheduled_finalization_time
          }
        }
      }

      {:ok, db_updates} = NewExits.get_db_update(events, statuses)
      assert [expected_db_update_1, expected_db_update_2] == db_updates
    end
  end
end
