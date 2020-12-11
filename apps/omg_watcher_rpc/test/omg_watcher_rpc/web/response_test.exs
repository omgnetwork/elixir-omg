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

defmodule OMG.WatcherRPC.Web.ResponseTest do
  # async: false because it needs to manipulate the global :api_mode application env.
  use ExUnit.Case, async: false
  alias OMG.WatcherRPC.Web.Response

  @app :omg_watcher_rpc

  setup do
    original_mode = Application.get_env(@app, :api_mode)

    on_exit(fn ->
      _ = Application.put_env(@app, :api_mode, original_mode)
    end)
  end

  describe "add_app_infos/1" do
    test "appends the given map with a service_name and semver-compliant version" do
      :ok = Application.put_env(@app, :api_mode, :watcher)

      assert %{foo: "bar", service_name: "watcher", version: version} = Response.add_app_infos(%{foo: "bar"})
      assert {:ok, _} = Version.parse(version)
    end

    test "appends the given map with the correct service_name" do
      :ok = Application.put_env(@app, :api_mode, :watcher)
      assert %{foo: "bar", service_name: "watcher"} = Response.add_app_infos(%{foo: "bar"})

      :ok = Application.put_env(@app, :api_mode, :watcher_info)
      assert %{foo: "bar", service_name: "watcher_info"} = Response.add_app_infos(%{foo: "bar"})
    end
  end
end
