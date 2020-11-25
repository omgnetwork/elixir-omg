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

defmodule OMG.WatcherInfo.HttpRPC.AdapterTest do
  use ExUnit.Case, async: true

  alias OMG.WatcherInfo.HttpRPC.Adapter

  describe "get_unparsed_response_body/1" do
    test "returns an unparsed body when successful" do
      body = "{\r\n  \"success\": true,\r\n  \"data\": {\r\n    \"test\": \"something\"\r\n  }\r\n}"
      assert {:ok, response} = Adapter.get_unparsed_response_body(%HTTPoison.Response{status_code: 200, body: body})
      assert response == %{"test" => "something"}
    end

    test "returns a `client_error` error with the data when failed" do
      body = "{\r\n  \"success\": false,\r\n  \"data\": {\r\n    \"test\": \"something\"\r\n  }\r\n}"
      assert {:error, response} = Adapter.get_unparsed_response_body(%HTTPoison.Response{status_code: 200, body: body})
      assert response == {:client_error, %{"test" => "something"}}
    end

    test "returns a `malformed_response` error with the data when the body is not recognized" do
      body = "{\r\n  \"malformed\": \"body\"\r\n}"
      assert {:error, response} = Adapter.get_unparsed_response_body(%HTTPoison.Response{status_code: 200, body: body})
      assert response == {:malformed_response, %{"malformed" => "body"}}
    end

    test "returns a `childchain_unreachable` error when `econnrefused` is returned" do
      assert {:error, :childchain_unreachable} =
               Adapter.get_unparsed_response_body({:error, %HTTPoison.Error{id: nil, reason: :econnrefused}})
    end

    test "returns the HTTPoison error reason when present" do
      assert {:error, :a_reason} =
               Adapter.get_unparsed_response_body({:error, %HTTPoison.Error{id: nil, reason: :a_reason}})
    end
  end

  describe "get_response_body/1" do
    test "returns a body with the key parsed when successful" do
      body = "{\r\n  \"success\": true,\r\n  \"data\": {\r\n    \"test\": \"something\"\r\n  }\r\n}"
      assert {:ok, response} = Adapter.get_response_body(%HTTPoison.Response{status_code: 200, body: body})
      assert response == %{test: "something"}
    end

    test "returns a `client_error` error with the data when failed" do
      body = "{\r\n  \"success\": false,\r\n  \"data\": {\r\n    \"test\": \"something\"\r\n  }\r\n}"
      assert {:error, response} = Adapter.get_response_body(%HTTPoison.Response{status_code: 200, body: body})
      assert response == {:client_error, %{"test" => "something"}}
    end

    test "returns a `malformed_response` error with the data when the body is not recognized" do
      body = "{\r\n  \"malformed\": \"body\"\r\n}"
      assert {:error, response} = Adapter.get_response_body(%HTTPoison.Response{status_code: 200, body: body})
      assert response == {:malformed_response, %{"malformed" => "body"}}
    end
  end
end
