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

defmodule OMG.WatcherRPC.Web.Controller.DepositTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.WatcherInfo.Fixtures

  import OMG.WatcherInfo.Factory

  alias OMG.Utils.HttpRPC.Encoding
  alias Support.WatcherHelper

  describe "get_deposits/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns API response with events" do
      _ = insert(:ethevent, txoutputs: [build(:txoutput)])

      request_body = %{"limit" => 10, "page" => 1}
      WatcherHelper.rpc_call("deposit.all", request_body, 200)

      assert %{
               "success" => true,
               "data" => [
                 %{
                   "event_type" => "deposit",
                   "eth_height" => _,
                   "log_index" => _,
                   "root_chain_txhash" => _,
                   "txoutputs" => [
                     %{
                       "amount" => _,
                       "blknum" => _,
                       "creating_txhash" => _,
                       "oindex" => _,
                       "otype" => _,
                       "owner" => _,
                       "spending_txhash" => _,
                       "txindex" => _
                     }
                   ]
                 }
               ],
               "data_paging" => %{
                 "limit" => 10,
                 "page" => 1
               },
               "service_name" => "watcher_info",
               "version" => _
             } = WatcherHelper.rpc_call("deposit.all", request_body, 200)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "filters events by address if address parameters given" do
      owner_1 = <<1::160>>
      owner_2 = <<2::160>>

      txo_1 = build(:txoutput, %{owner: owner_1})
      txo_2 = build(:txoutput, %{owner: owner_2})

      _ = insert(:ethevent, event_type: :deposit, txoutputs: [txo_1])
      _ = insert(:ethevent, event_type: :deposit, txoutputs: [txo_2])

      address = Encoding.to_hex(owner_1)
      request_body = %{"address" => address}

      %{
        "data" => [
          %{"txoutputs" => [deposit_txo]}
        ]
      } = WatcherHelper.rpc_call("deposit.all", request_body, 200)

      assert deposit_txo["owner"] == address
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns expected error if invalid parameters are given" do
      incorrect_address = 0
      request_body = %{"address" => incorrect_address}

      assert %{
               "data" => %{
                 "code" => "operation:bad_request",
                 "description" => "Parameters required by this operation are missing or incorrect.",
                 "messages" => %{
                   "validation_error" => %{"parameter" => "address", "validator" => ":hex"}
                 },
                 "object" => "error"
               },
               "service_name" => "watcher_info",
               "success" => false,
               "version" => _
             } = WatcherHelper.rpc_call("deposit.all", request_body, 200)
    end
  end
end
