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

  alias OMG.TestHelper, as: Test
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.WatcherInfo.DB
  alias Support.WatcherHelper

  @default_data_paging %{"limit" => 200, "page" => 1}

  describe "get_block\2" do
    @tag fixtures: [:initial_blocks]
    test "/block.get endpoint rejects parameter of length unequal to 32" do
      too_short_addr = %{hash: "0x" <> String.duplicate("00", 20)}

      assert %{
               "success" => false,
               "data" => %{
                 "object" => "error",
                 "code" => "operation:bad_request",
                 "messages" => %{
                   "validation_error" => %{
                     "parameter" => "hash",
                     "validator" => "{:length, 32}"
                   }
                 }
               }
             } = WatcherHelper.rpc_call(:post, "block.get", too_short_addr)
    end
  end
end
