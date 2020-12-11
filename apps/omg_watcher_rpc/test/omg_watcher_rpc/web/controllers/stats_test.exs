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

defmodule OMG.WatcherRPC.Web.Controller.StatsTet do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.WatcherInfo.Fixtures

  alias Support.WatcherHelper

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

      %{"data" => data} = WatcherHelper.rpc_call("stats.get", %{}, 200)

      expected = %{
        "block_count" => %{"all_time" => 2, "last_24_hours" => 1},
        "transaction_count" => %{"all_time" => 4, "last_24_hours" => 2},
        "average_block_interval_seconds" => %{"all_time" => 200.0, "last_24_hours" => nil}
      }

      assert data == expected
    end
  end
end
