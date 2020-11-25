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
# limitations under the License
defmodule OMG.Utils.RemoteIPTest do
  use ExUnit.Case, async: true

  alias OMG.Utils.RemoteIP

  describe "call/2" do
    test "sets remote_ip field" do
      conn = %Plug.Conn{
        req_headers: [
          {"cf-connecting-ip", "99.99.99.99"}
        ]
      }

      conn_with_remote_ip = RemoteIP.call(conn, %{})

      assert conn_with_remote_ip.remote_ip == {99, 99, 99, 99}
    end

    test "does not set remote_ip if cf-connecting-ip header is not set" do
      conn = %Plug.Conn{}

      conn_with_remote_ip = RemoteIP.call(conn, %{})

      assert is_nil(conn_with_remote_ip.remote_ip)
    end

    test "does not set remote_ip if cf-connecting-ip header is invalid" do
      conn = %Plug.Conn{
        req_headers: [
          {"cf-connecting-ip", "myip"}
        ]
      }

      conn_with_remote_ip = RemoteIP.call(conn, %{})

      assert is_nil(conn_with_remote_ip.remote_ip)
    end

    test "sets the left-most ip address" do
      conn = %Plug.Conn{
        req_headers: [
          {"cf-connecting-ip", "77.77.77.77, 99.99.99.99"}
        ]
      }

      conn_with_remote_ip = RemoteIP.call(conn, %{})

      assert conn_with_remote_ip.remote_ip == {77, 77, 77, 77}
    end
  end
end
