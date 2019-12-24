
# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.WatcherRPC.Web.Validator.UtxoConstraintsTest do
  use ExUnit.Case, async: true

  import OMG.Eth.Encoding, only: [to_hex: 1]

  alias OMG.WatcherRPC.Web.Validator.UtxoConstraints

  @eth_addr_hex to_hex(OMG.Eth.RootChain.eth_pseudo_address())

  describe "parse/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns deposit constraints when given owner address" do
      request_data = %{"address" => @eth_addr_hex, "page" => 1, "limit" => 100}

      {:ok, constraints} = UtxoConstraints.parse(request_data)

      IO.inspect(constraints, label: "contstraints")

      assert constraints == [page: 1, limit: 100, address: @eth_addr]
    end

    test "returns error when owner address is an invalid address" do
      # addresses are only 160 bits
      request_data = %{"address" => <<0::256>>, "page" => 1, "limit" => 100}

      {:error, error_data} = UtxoConstraints.parse(request_data)

      assert error_data == {:validation_error, "address", :hex}
    end
  end
end
