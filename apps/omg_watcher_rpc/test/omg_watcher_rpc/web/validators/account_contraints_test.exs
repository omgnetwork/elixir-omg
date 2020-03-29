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

defmodule OMG.WatcherRPC.Web.Validator.AccountConstraintsTest do
  @moduledoc """
  Account constraints validate test
  """
  use ExUnit.Case, async: true

  alias OMG.Eth.Encoding
  alias OMG.WatcherRPC.Web.Validator.AccountConstraints

  @fake_address_hex_string "0x7977fe798feef376b74b6c1c5ebce8a2ccf02afd"

  describe("parse/1") do
    test "returns page, limit and adress constraints when given page, limit and adress" do
      request_data = %{
        "page" => 1,
        "limit" => 100,
        "address" => @fake_address_hex_string
      }

      {:ok, constraints} = AccountConstraints.parse(request_data)

      assert constraints == [
               address: Encoding.from_hex(@fake_address_hex_string),
               page: 1,
               limit: 100
             ]
    end

    test "return error if does not provide address" do
      request_data = %{
        "page" => 1,
        "limit" => 100
      }

      assert AccountConstraints.parse(request_data) == {:error, {:validation_error, "address", :hex}}
    end

    test "return error if limit exceed 500" do
      request_data = %{
        "address" => Encoding.from_hex(@fake_address_hex_string),
        "page" => 1,
        "limit" => 600
      }

      assert AccountConstraints.parse(request_data) == {:error, {:validation_error, "limit", {:lesser, 500}}}
    end

    test "return address if only address is provided" do
      request_data = %{
        "address" => @fake_address_hex_string
      }

      {:ok, constraints} = AccountConstraints.parse(request_data)

      assert constraints == [
               address: Encoding.from_hex(@fake_address_hex_string)
             ]
    end
  end
end
