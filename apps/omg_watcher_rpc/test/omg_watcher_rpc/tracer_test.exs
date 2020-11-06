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

defmodule OMG.WatcherRPC.TracerTest do
  use ExUnit.Case, async: true
  alias OMG.WatcherRPC.Tracer

  test "api responses without errors are traced" do
    resp_body = """
    {
      "data": [],
      "service_name": "watcher",
      "success": true,
      "version": "1.0.4+33c3300"
    }
    """

    conn =
      Phoenix.ConnTest.build_conn(:get, "/alerts.get")
      |> Plug.Conn.resp(200, resp_body)

    actual_trace = Tracer.add_trace_metadata(conn)

    expected_trace =
      Keyword.new([
        {:tags, [version: "1.0.4+33c3300"]},
        {:service, :watcher},
        {:http, [method: "GET", query_string: "", status_code: 200, url: "/alerts.get", user_agent: nil]},
        {:resource, "GET /alerts.get"},
        {:type, :web}
      ])

    assert expected_trace == actual_trace
  end

  test "if api responses with errors are traced" do
    resp_body = """
    {
      "data": {
      "code": "operation:not_found",
      "description": "Operation cannot be found. Check request URL.",
      "object": "error"
      },
      "service_name": "watcher_info",
      "success": false,
      "version": "1.0.4+33c3300"
    }
    """

    conn =
      Phoenix.ConnTest.build_conn(:post, "/")
      |> Plug.Conn.resp(200, resp_body)

    actual_trace = Tracer.add_trace_metadata(conn)

    expected_trace =
      Keyword.new([
        {:error, [error: true]},
        {:tags, [version: "1.0.4+33c3300"]},
        {:service, :watcher_info},
        {:http, [method: "POST", query_string: "", status_code: 200, url: "/", user_agent: nil]},
        {:resource, "POST /"},
        {:type, :web}
      ])

    assert expected_trace == actual_trace
  end

  test "conn with unparseable resp body is still traced" do
    resp_body = "foo"

    conn =
      Phoenix.ConnTest.build_conn(:post, "/foo.get")
      |> Plug.Conn.resp(200, resp_body)

    actual_trace = Tracer.add_trace_metadata(conn)

    expected_trace =
      Keyword.new([
        {:http, [method: "POST", query_string: "", status_code: 200, url: "/foo.get", user_agent: nil]},
        {:resource, "POST /foo.get"},
        {:type, :web}
      ])

    assert expected_trace == actual_trace
  end
end
