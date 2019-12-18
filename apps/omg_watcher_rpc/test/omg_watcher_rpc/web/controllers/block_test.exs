# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.WatcherRPC.Web.Controller.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.WatcherInfo.Fixtures
  use OMG.Watcher.Fixtures

  import OMG.WatcherInfo.Factory

  alias Support.WatcherHelper

  describe "get_block/2" do
    @tag fixtures: [:initial_blocks]
    test "/block.get returns correct block if existent" do
      existent_blknum = 1000

      %{"success" => success, "data" => data} = WatcherHelper.rpc_call("block.get", %{blknum: existent_blknum}, 200)

      assert data["blknum"] == existent_blknum
      assert success == true
    end

    @tag fixtures: [:initial_blocks]
    test "/block.get rejects parameter of wrong type" do
      string_blknum = "1000"
      %{"data" => data} = WatcherHelper.rpc_call("block.get", %{blknum: string_blknum}, 200)

      expected = %{
        "code" => "operation:bad_request",
        "description" => "Parameters required by this operation are missing or incorrect.",
        "messages" => %{"validation_error" => %{"parameter" => "blknum", "validator" => ":integer"}},
        "object" => "error"
      }

      assert data == expected
    end

    @tag fixtures: [:initial_blocks]
    test "/block.get endpoint rejects request without parameters" do
      missing_param = %{}
      %{"data" => data} = WatcherHelper.rpc_call("block.get", missing_param, 200)

      expected = %{
        "code" => "operation:bad_request",
        "description" => "Parameters required by this operation are missing or incorrect.",
        "messages" => %{"validation_error" => %{"parameter" => "blknum", "validator" => ":integer"}},
        "object" => "error"
      }

      assert data == expected
    end

    @tag fixtures: [:initial_blocks]
    test "/block.get returns expected error if block not found" do
      non_existent_block = 5000
      %{"data" => data} = WatcherHelper.rpc_call("block.get", %{blknum: non_existent_block}, 200)

      expected = %{
        "code" => "get_block:block_not_found",
        "description" => nil,
        "object" => "error"
      }

      assert data == expected
  describe "get_blocks/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns the API response with the blocks" do
      _ = insert(:block, blknum: 1000, hash: <<1>>, eth_height: 1, timestamp: 100)
      _ = insert(:block, blknum: 2000, hash: <<2>>, eth_height: 2, timestamp: 200)

      request_data = %{"limit" => 200, "page" => 1}
      response = WatcherHelper.rpc_call("block.all", request_data, 200)

      assert %{
               "success" => true,
               "data" => [
                 %{
                   "blknum" => 2000,
                   "eth_height" => 2,
                   "hash" => "0x02",
                   "timestamp" => 200
                 },
                 %{
                   "blknum" => 1000,
                   "eth_height" => 1,
                   "hash" => "0x01",
                   "timestamp" => 100
                 }
               ],
               "data_paging" => %{
                 "limit" => 100,
                 "page" => 1
               },
               "service_name" => _,
               "version" => _
             } = response
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns the error API response when an error occurs" do
      request_data = %{"limit" => "this should error", "page" => 1}
      response = WatcherHelper.rpc_call("block.all", request_data, 200)

      assert %{
               "success" => false,
               "data" => %{
                 "object" => "error",
                 "code" => "operation:bad_request",
                 "description" => "Parameters required by this operation are missing or incorrect.",
                 "messages" => _
               },
               "service_name" => _,
               "version" => _
             } = response
    end
  end
end
