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

defmodule OMG.WatcherInfo.API.StatsTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.WatcherInfo.Fixtures

  alias OMG.WatcherInfo.API.Stats
  alias OMG.WatcherInfo.DB

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @seconds_in_twenty_four_hours 86_400

  describe "get/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "retrieves expected statistics" do
      now = DateTime.to_unix(DateTime.utc_now())

      within_today = now - @seconds_in_twenty_four_hours + 100
      before_today = now - @seconds_in_twenty_four_hours - 100

      alice = OMG.TestHelper.generate_entity()
      bob = OMG.TestHelper.generate_entity()

      tx_1 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}])
      tx_2 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 500}])
      tx_3 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 700}])
      tx_4 = OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 900}])

      mined_block_1 = %{
        transactions: [tx_1, tx_2],
        blknum: 1000,
        blkhash: "0x1000",
        timestamp: before_today,
        eth_height: 1
      }

      mined_block_2 = %{
        transactions: [tx_3, tx_4],
        blknum: 2000,
        blkhash: "0x2000",
        timestamp: within_today,
        eth_height: 1
      }

      _ = DB.Block.insert_with_transactions(mined_block_1)
      _ = DB.Block.insert_with_transactions(mined_block_2)

      result = Stats.get()

      expected =
        {:ok,
         %{
           block_count: %{all_time: 2, last_24_hours: 1},
           transaction_count: %{all_time: 4, last_24_hours: 2},
           average_block_interval_seconds: %{all_time: 200.0, last_24_hours: nil}
         }}

      assert result == expected
    end
  end

  describe "get_average_block_interval/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "correctly returns average difference where two blocks or more exist" do
      base = 100
      [diff_1, diff_2, diff_3] = [10, 10, 30]

      timestamps = [
        %{timestamp: base},
        %{timestamp: base + diff_1},
        %{timestamp: base + diff_1 + diff_2},
        %{timestamp: base + diff_1 + diff_2 + diff_3}
      ]

      result = Stats.get_average_block_interval(timestamps)

      assert result == (diff_1 + diff_2 + diff_3) / 3
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns nil if number of blocks is smaller than 2" do
      timestamps_1 = []
      result_1 = Stats.get_average_block_interval(timestamps_1)
      assert result_1 == nil

      timestamps_2 = [%{timestamp: 100}]
      result_2 = Stats.get_average_block_interval(timestamps_2)
      assert result_2 == nil

      timestamps_3 = [%{timestamp: 100}, %{timestamp: 200}]
      result_3 = Stats.get_average_block_interval(timestamps_3)
      assert result_3 == 100
    end
  end
end
