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

defmodule OMG.WatcherInfo.API.StatsTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.WatcherInfo.Fixtures

  alias OMG.WatcherInfo.API.Stats

  import OMG.WatcherInfo.Factory

  @seconds_in_twenty_four_hours 86_400

  describe "get/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "retrieves expected statistics" do
      now = DateTime.to_unix(DateTime.utc_now())

      within_today = now - @seconds_in_twenty_four_hours + 100
      before_today = now - @seconds_in_twenty_four_hours - 100

      block_1 = insert(:block, blknum: 1000, timestamp: within_today)
      _ = insert(:transaction, block: block_1, txindex: 0)
      _ = insert(:transaction, block: block_1, txindex: 1)

      block_2 = insert(:block, blknum: 2000, timestamp: before_today)
      _ = insert(:transaction, block: block_2, txindex: 0)
      _ = insert(:transaction, block: block_2, txindex: 1)

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

  describe "get_average_block_interval_all_time/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "correctly returns the average difference of block timestamps for all time" do
      base = 100
      [diff_1, diff_2, diff_3] = [10, 10, 30]

      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: base)
      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: base + diff_1)
      _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: base + diff_1 + diff_2)
      _ = insert(:block, blknum: 4000, hash: "0x4000", eth_height: 4, timestamp: base + diff_1 + diff_2 + diff_3)

      expected = (diff_1 + diff_2 + diff_3) / 3

      actual = Stats.get_average_block_interval_all_time()

      assert expected == actual
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns nil if the number of blocks is less than 2" do
      result_1 = Stats.get_average_block_interval_all_time()
      assert result_1 == nil

      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)
      result_2 = Stats.get_average_block_interval_all_time()
      assert result_2 == nil

      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: 200)
      result_3 = Stats.get_average_block_interval_all_time()
      assert result_3 == 100
    end
  end

  describe "get_average_block_interval_between/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "correctly returns the average difference of block timestamps in the given time range" do
      end_datetime = DateTime.to_unix(DateTime.utc_now())
      start_datetime = end_datetime - @seconds_in_twenty_four_hours
      [diff_1, diff_2] = [80, 90]

      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: start_datetime - 100)
      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: start_datetime)
      _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: start_datetime + diff_1)
      _ = insert(:block, blknum: 4000, hash: "0x4000", eth_height: 4, timestamp: start_datetime + diff_1 + diff_2)

      expected = (diff_1 + diff_2) / 2

      actual = Stats.get_average_block_interval_between(start_datetime, end_datetime)

      assert expected == actual
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns nil if the number of blocks in the given time range is less than 2" do
      end_datetime = DateTime.to_unix(DateTime.utc_now())
      start_datetime = end_datetime - @seconds_in_twenty_four_hours

      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: start_datetime - 100)
      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: start_datetime - 50)

      result_1 = Stats.get_average_block_interval_between(start_datetime, end_datetime)
      assert result_1 == nil

      _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: start_datetime)
      result_2 = Stats.get_average_block_interval_between(start_datetime, end_datetime)
      assert result_2 == nil

      _ = insert(:block, blknum: 4000, hash: "0x4000", eth_height: 4, timestamp: start_datetime + 100)
      result_2 = Stats.get_average_block_interval_between(start_datetime, end_datetime)
      assert result_2 == 100
    end
  end
end
