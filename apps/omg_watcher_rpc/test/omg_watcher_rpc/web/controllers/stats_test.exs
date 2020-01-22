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

defmodule OMG.WatcherRPC.Web.Controller.StatsTet do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.WatcherInfo.Fixtures

  alias OMG.WatcherInfo.DB
  alias Support.WatcherHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  describe "get/0" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "retrieves expected statistics" do
      now = DateTime.to_unix(DateTime.utc_now())
      twenty_four_hours = 86_400
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

      %{"data" => data} = WatcherHelper.rpc_call("stats.get", %{}, 200)

      expected = %{
        "block_count" => %{"all_time" => 2, "last_24_hours" => 1},
        "transaction_count" => %{"all_time" => 4, "last_24_hours" => 2},
        "average_block_interval" => %{"all_time" => 200.0, "last_24_hours" => "N/A"}
      }

      assert data == expected
    end
  end
end
