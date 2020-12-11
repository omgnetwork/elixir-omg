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

defmodule OMG.WatcherRPC.Web.Plugs.SupportedWatcherModesTest do
  # async: false because it needs to manipulate the global :api_mode application env.
  use ExUnit.Case, async: false
  use Plug.Test

  alias OMG.WatcherRPC.Web.Plugs.SupportedWatcherModes

  @app :omg_watcher_rpc

  setup do
    original_mode = Application.get_env(@app, :api_mode)

    on_exit(fn ->
      _ = Application.put_env(@app, :api_mode, original_mode)
    end)

    conn =
      :post
      |> conn("/some_endpoint", %{})
      |> Phoenix.Controller.accepts(["json"])

    {:ok, %{conn: conn}}
  end

  test "returns the original conn if the API mode matches a supported modes", context do
    :ok = Application.put_env(@app, :api_mode, :watcher_info)
    conn = SupportedWatcherModes.call(context.conn, [:watcher, :watcher_info])

    assert conn == context.conn
  end

  test "returns operation:not_found if the API mode does not match a supported modes", context do
    :ok = Application.put_env(@app, :api_mode, :watcher)
    conn = SupportedWatcherModes.call(context.conn, [:watcher_info])

    assert conn.assigns[:code] == "operation:not_found"
  end
end
