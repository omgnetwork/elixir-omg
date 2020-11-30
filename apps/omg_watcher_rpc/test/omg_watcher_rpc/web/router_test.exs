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

defmodule OMG.WatcherRPC.Web.RouterTest do
  # async: false as we need to change :api_mode application env.
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.WatcherInfo.Fixtures

  alias Support.WatcherHelper

  setup do
    original_mode = Application.get_env(:omg_watcher_rpc, :api_mode)
    _ = on_exit(fn -> Application.put_env(:omg_watcher_rpc, :api_mode, original_mode) end)

    :ok
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "returns a successful response when calling an :info_api endpoint from :watcher_info mode" do
    :ok = Application.put_env(:omg_watcher_rpc, :api_mode, :watcher_info)
    assert WatcherHelper.success?("transaction.all", %{})
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "returns an error response when calling an :info_api endpoint from :watcher mode" do
    :ok = Application.put_env(:omg_watcher_rpc, :api_mode, :watcher)

    assert %{
             "object" => "error",
             "code" => "operation:not_found",
             "description" => "Operation cannot be found. Check request URL."
           } == WatcherHelper.no_success?("transaction.all", %{})
  end
end
