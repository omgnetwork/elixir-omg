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

  alias Support.WatcherHelper
  alias OMG.WatcherInfo.DB

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  describe "get/0" do
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
        timestamp: within_today,
        eth_height: 1
      }

      mined_block_2 = %{
        transactions: [tx_3, tx_4],
        blknum: 1000,
        blkhash: "0x1000",
        timestamp: before_today,
        eth_height: 1
      }

      _ = DB.Block.insert_with_transactions(mined_block_1)
      _ = DB.Block.insert_with_transactions(mined_block_2)

      result = WatcherHelper.rpc_call("stats.get", %{}, 200)

      expected = %{
        "data" => %{
          "blocks" => %{"all_time" => 1, "last_24_hours" => 1},
          "transactions" => %{"count" => %{"all_time" => 2, "last_24_hours" => 2}}
        },
        "service_name" => "child_chain",
        "success" => true,
        "version" => "0.3.0+df1b4bb"
      }

      assert result == expected
    end
  end
end
