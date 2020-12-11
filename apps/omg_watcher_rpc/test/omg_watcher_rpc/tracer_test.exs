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

defmodule OMG.WatcherRPC.TracerTest do
  @app :omg_watcher_rpc

  use ExUnit.Case
  import Plug.Conn
  alias OMG.WatcherRPC.Configuration
  alias OMG.WatcherRPC.Tracer

  setup do
    original_mode = Application.get_env(:omg_watcher_rpc, :api_mode)
    _ = on_exit(fn -> Application.put_env(:omg_watcher_rpc, :api_mode, original_mode) end)

    :ok
  end

  test "api responses without errors get traced with metadata" do
    :ok = Application.put_env(@app, :api_mode, :watcher)
    version = Configuration.version()

    resp_body = """
    {
      "data": [],
      "service_name": "watcher",
      "success": true,
      "version": "#{version}"
    }
    """

    conn =
      :get
      |> Phoenix.ConnTest.build_conn("/alerts.get")
      |> Plug.Conn.resp(200, resp_body)

    trace_metadata = Tracer.add_trace_metadata(conn)

    expected =
      Keyword.new([
        {:tags, [version: version]},
        {:service, :watcher},
        {:http, [method: "GET", query_string: "", status_code: 200, url: "/alerts.get", user_agent: nil]},
        {:resource, "GET /alerts.get"},
        {:type, :web}
      ])

    assert trace_metadata == expected
  end

  test "if api responses with errors get traced with metadata" do
    :ok = Application.put_env(@app, :api_mode, :watcher_info)
    version = Configuration.version()

    resp_body = """
    {
      "data": {
      "code": "operation:not_found",
      "description": "Operation cannot be found. Check request URL.",
      "object": "error"
      },
      "service_name": "watcher_info",
      "success": false,
      "version": "#{version}"
    }
    """

    conn =
      :post
      |> Phoenix.ConnTest.build_conn("/")
      |> Plug.Conn.resp(200, resp_body)
      |> assign(:error_type, "operation:not_found")
      |> assign(:error_msg, "Operation cannot be found. Check request URL.")

    trace_metadata = Tracer.add_trace_metadata(conn)

    expected =
      Keyword.new([
        {
          :tags,
          [
            {:version, version},
            {:"error.type", "operation:not_found"},
            {:"error.msg", "Operation cannot be found. Check request URL."}
          ]
        },
        {:error, [error: true]},
        {:service, :watcher_info},
        {:http, [method: "POST", query_string: "", status_code: 200, url: "/", user_agent: nil]},
        {:resource, "POST /"},
        {:type, :web}
      ])

    assert trace_metadata == expected
  end
end
