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

defmodule OMG.Watcher.HttpRPC.AdapterTest do
  use ExUnit.Case, async: true

  import FakeServer

  alias OMG.Utils.AppVersion
  alias OMG.Watcher.HttpRPC.Adapter

  describe "rpc_post/3" do
    test_with_server "includes X-Watcher-Version header" do
      route("/path", FakeServer.Response.ok())
      _ = Adapter.rpc_post(%{}, "path", FakeServer.address())

      expected_watcher_version = AppVersion.version(:omg_watcher_info)

      assert request_received(
               "/path",
               method: "POST",
               headers: %{"content-type" => "application/json", "x-watcher-version" => expected_watcher_version}
             )
    end
  end
end
