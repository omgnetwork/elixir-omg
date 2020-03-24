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

  describe "parse/1" do
    test "returns page and limit constraints when given page and limit params and adress" do
      request_data = %{
        "page" => 1,
        "limit" => 100,
        "address" => "0x7977fe798feef376b74b6c1c5ebce8a2ccf02afd"
      }

      {:ok, constraints} = AccountConstraints.parse(request_data)

      assert constraints == [
               address:
                 <<121, 119, 254, 121, 143, 238, 243, 118, 183, 75, 108, 28, 94, 188, 232, 162, 204, 240, 42, 253>>,
               page: 1,
               limit: 100
             ]
    end
  end
end
