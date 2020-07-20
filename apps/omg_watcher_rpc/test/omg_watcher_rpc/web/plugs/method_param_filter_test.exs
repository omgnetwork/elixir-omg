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

defmodule OMG.WatcherRPC.Web.Plugs.MethodParamFilterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias OMG.WatcherRPC.Web.Plugs.MethodParamFilter

  # this test seems like it's reaching far to deep into internals of plugs
  test "filters query params for POST" do
    conn =
      :post
      |> conn("/some_endpoint?foo=bar", %{"foo_1" => "bar_1"})
      |> Plug.Parsers.call({[:json], [], nil, false})
      |> MethodParamFilter.call([])

    assert conn.body_params == %{"foo_1" => "bar_1"}
    assert conn.query_params == %{}
    assert conn.params == %{"foo_1" => "bar_1"}
  end

  # this test seems like it's reaching far to deep into internals of plugs
  test "filters body params for GET" do
    conn =
      :get
      |> conn("/some_endpoint?foo=bar", %{"foo_1" => "bar_1"})
      |> Plug.Parsers.call({[:json], [], nil, false})
      |> MethodParamFilter.call([])

    assert conn.body_params == %{}
    assert conn.query_params == %{"foo" => "bar"}
    assert conn.params == %{"foo" => "bar"}
  end

  test "returns original conn for other methods" do
    original_conn = conn(:put, "/some_endpoint?foo=bar", %{"foo_1" => "bar_1"})

    assert MethodParamFilter.call(original_conn, []) == original_conn
  end
end
