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

  alias OMG.State.Transaction
  alias OMG.TestHelper, as: Test
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.WatcherInfo.DB
  alias Support.WatcherHelper

  @default_data_paging %{"limit" => 200, "page" => 1}

  describe "get_blocks/2" do
    @tag fixtures: [:initial_blocks]
    test "" do
# {[
#    %{
#      "blknum" => 3000,
#      "eth_height" => 1,
#      "hash" => "0x2333303030",
#      "timestamp" => 1540465606
#    },
#    %{
#      "blknum" => 2000,
#      "eth_height" => 1,
#      "hash" => "0x2332303030",
#      "timestamp" => 1540465606
#    },
#    %{
#      "blknum" => 1000,
#      "eth_height" => 1,
#      "hash" => "0x2331303030",
#      "timestamp" => 1540465606
#    }
#  ], %{"limit" => 100, "page" => 1}}
      block_all_with_paging(@default_data_paging) |> IO.inspect()
    end
  end

  defp block_all_with_paging(body) do
    %{
      "success" => true,
      "data" => data,
      "data_paging" => paging
    } = WatcherHelper.rpc_call("block.all", body, 200)

    {data, paging}
  end
end
