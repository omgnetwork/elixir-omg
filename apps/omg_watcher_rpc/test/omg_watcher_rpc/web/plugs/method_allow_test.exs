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

defmodule OMG.WatcherRPC.Web.Plugs.MethodAllowTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias OMG.ChildChainRPC.Web.TestHelper
  alias OMG.WatcherRPC.Web.Plugs.MethodAllow

  test "allows if the HTTP request method is GET" do
    init_conn = conn(:get, "/foo", %{})

    assert MethodAllow.call(init_conn, []) == init_conn
  end

  test "allows if the HTTP request method is POST" do
    init_conn = conn(:post, "/foo", %{})

    assert MethodAllow.call(init_conn, []) == init_conn
  end

  test "disallows if the HTTP request method is neither GET nor POST" do
    assert catch_error(
      %{
        "data" => %{
          "code" => "operation:method_not_allowed",
          "message" => "PUT is not allowed."
        }
      } = TestHelper.rpc_call(:put, "/status.get", %{})
    )

    assert catch_error(
      %{
        "data" => %{
          "code" => "operation:method_not_allowed",
          "message" => "HEAD is not allowed."
        }
      } = TestHelper.rpc_call(:head, "/status.get", %{})
    )

    assert catch_error(
      %{
        "data" => %{
          "code" => "operation:method_not_allowed",
          "message" => "DELETE is not allowed."
        }
      } = TestHelper.rpc_call(:delete, "/status.get", %{})
    )

    assert catch_error(
      %{
        "data" => %{
          "code" => "operation:method_not_allowed",
          "message" => "OPTION is not allowed."
        }
      } = TestHelper.rpc_call(:option, "/status.get", %{})
    )

    assert catch_error(
      %{
        "data" => %{
          "code" => "operation:method_not_allowed",
          "message" => "TRACE is not allowed."
        }
      } = TestHelper.rpc_call(:trace, "/status.get", %{})
    )

    assert catch_error(
      %{
        "data" => %{
          "code" => "operation:method_not_allowed",
          "message" => "PATCH is not allowed."
        }
      } = TestHelper.rpc_call(:patch, "/status.get", %{})
    )
  end

end
