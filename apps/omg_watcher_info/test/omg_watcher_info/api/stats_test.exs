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

defmodule OMG.WatcherInfo.API.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.WatcherInfo.Fixtures

  import OMG.WatcherInfo.Factory

  alias OMG.WatcherInfo.API.Stats
  alias OMG.WatcherInfo.DB

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  describe "get_stats/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "retrieves expected statistics" do
      now = DateTime.to_unix(DateTime.utc_now())
      twenty_four_hours = 86400
      within_today = now - twenty_four_hours + 100
      before_today = now - twenty_four_hours - 100

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
           average_block_interval: %{all_time: 200.0, last_24_hours: :"N/A"}
         }}

      assert result == expected
    end
  end

  describe "get_average_block_interval/0" do
    test "average function returns average correctly" do
      array_1 = [10]
      array_2 = [4, 4, 5, 5]

      expected_1 = 10
      expected_2 = 4.5

      actual_1 = Stats.average(array_1)
      actual_2 = Stats.average(array_2)

      assert actual_1 == expected_1
      assert actual_2 == expected_2
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "correctly returns average difference where two blocks or more exist" do
      base = 100
      [diff_1, diff_2, diff_3] = [10, 10, 30]

      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: base)
      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: base + diff_1)
      _ = insert(:block, blknum: 3000, hash: "0x3000", eth_height: 3, timestamp: base + diff_1 + diff_2)
      _ = insert(:block, blknum: 4000, hash: "0x4000", eth_height: 4, timestamp: base + diff_1 + diff_2 + diff_3)

      timestamps = DB.Block.get_timestamps()
      result = Stats.get_average_block_interval(timestamps)

      assert result == Stats.average([diff_1, diff_2, diff_3])
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns N/A if number of blocks is smaller than 2" do
      timestamps_1 = DB.Block.get_timestamps()
      result_1 = Stats.get_average_block_interval(timestamps_1)
      assert result_1 == :"N/A"

      _ = insert(:block, blknum: 1000, hash: "0x1000", eth_height: 1, timestamp: 100)

      timestamps_2 = DB.Block.get_timestamps()
      result_2 = Stats.get_average_block_interval(timestamps_2)
      assert result_2 == :"N/A"

      _ = insert(:block, blknum: 2000, hash: "0x2000", eth_height: 2, timestamp: 200)

      timestamps_3 = DB.Block.get_timestamps()
      result_3 = Stats.get_average_block_interval(timestamps_3)
      assert result_3 == 100
    end
  end
end
