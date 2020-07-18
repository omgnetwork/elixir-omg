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

defmodule OMG.WatcherRPC.Web.Plugs.HttpMethodAllowTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  alias OMG.WatcherRPC.Web.Plugs.HttpMethodAllow

  test "returns the original conn if the HTTP request method is GET" do
    init_conn = build_conn(:get, "/foo", %{})

    assert HttpMethodAllow.call(init_conn, []) == init_conn
  end

  test "returns the original conn if the HTTP request method is POST" do
    init_conn = build_conn(:post, "/foo", %{})

    assert HttpMethodAllow.call(init_conn, []) == init_conn
  end

  test "returns operation:http_method_not_allowed if the HTTP request method is neither GET nor POST" do
    # PUT
    %Plug.Conn{resp_body: response} = :put
      |> build_conn("/foo", %{})
      |> HttpMethodAllow.call([])

    assert Jason.decode!(response) == %{
      "data" => %{"code" => "operation:http_method_not_allowed", "description" => "PUT is not allowed.", "object" => "error"},
      "success" => false
    }

    # PATCH
    %Plug.Conn{resp_body: response} = :patch
      |> build_conn("/foo", %{})
      |> HttpMethodAllow.call([])

    assert Jason.decode!(response) == %{
      "data" => %{"code" => "operation:http_method_not_allowed", "description" => "PATCH is not allowed.", "object" => "error"},
      "success" => false
    }

    # DELETE
    %Plug.Conn{resp_body: response} = :delete
      |> build_conn("/foo", %{})
      |> HttpMethodAllow.call([])

    assert Jason.decode!(response) == %{
      "data" => %{"code" => "operation:http_method_not_allowed", "description" => "DELETE is not allowed.", "object" => "error"},
      "success" => false
    }

    # OPTION
    %Plug.Conn{resp_body: response} = :option
      |> build_conn("/foo", %{})
      |> HttpMethodAllow.call([])

    assert Jason.decode!(response) == %{
      "data" => %{"code" => "operation:http_method_not_allowed", "description" => "OPTION is not allowed.", "object" => "error"},
      "success" => false
    }

    # TRACE
    %Plug.Conn{resp_body: response} = :trace
      |> build_conn("/foo", %{})
      |> HttpMethodAllow.call([])

    assert Jason.decode!(response) == %{
      "data" => %{"code" => "operation:http_method_not_allowed", "description" => "TRACE is not allowed.", "object" => "error"},
      "success" => false
    }
  end
end
