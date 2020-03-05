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

defmodule OMG.WatcherRPC.Web.Controller.UtxoTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.WatcherInfo.Fixtures

  alias OMG.Utxo
  alias Support.WatcherHelper
  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:db_initialized]
  test "get_exit_data should return error when there is no txs in specfic block" do
    assert %{
             "code" => "exit:invalid",
             "description" => "Utxo was spent or does not exist.",
             "object" => "error"
           } ==
             WatcherHelper.no_success?("utxo.get_exit_data", %{
               "utxo_pos" => Utxo.position(7001, 1, 0) |> Utxo.Position.encode()
             })
  end

  @tag fixtures: [:db_initialized]
  test "get_exit_data should return error when there is no tx in specfic block" do
    assert %{
             "code" => "exit:invalid",
             "description" => "Utxo was spent or does not exist.",
             "object" => "error"
           } ==
             WatcherHelper.no_success?("utxo.get_exit_data", %{
               "utxo_pos" => Utxo.position(7000, 1, 0) |> Utxo.Position.encode()
             })
  end

  @tag fixtures: [:db_initialized, :bob]
  test "getting exit data returns properly formatted response", %{bob: bob} do
    tx = OMG.TestHelper.create_signed([{1, 0, 0, bob}], @eth, [{bob, 100}])
    tx_encode = tx |> OMG.State.Transaction.Signed.encode()

    OMG.DB.multi_update([
      {:put, :utxo,
       {{1000, 0, 0},
        %{amount: 100, creating_txhash: OMG.State.Transaction.raw_txhash(tx), currency: @eth, owner: bob.addr}}},
      {:put, :block, %{number: 1000, hash: <<>>, transactions: [tx_encode]}}
    ])

    %{
      "utxo_pos" => _utxo_pos,
      "txbytes" => _txbytes,
      "proof" => proof
    } = WatcherHelper.get_exit_data(1000, 0, 0)

    assert <<_proof::bytes-size(512)>> = proof
  end

  @tag fixtures: [:db_initialized]
  test "getting exit data returns error when there is no txs in specfic block" do
    utxo_pos = Utxo.position(7000, 1, 0) |> Utxo.Position.encode()

    assert %{
             "object" => "error",
             "code" => "exit:invalid",
             "description" => "Utxo was spent or does not exist."
           } = WatcherHelper.no_success?("utxo.get_exit_data", %{"utxo_pos" => utxo_pos})
  end

  test "utxo.get_exit_data handles improper type of parameter" do
    assert %{
             "object" => "error",
             "code" => "operation:bad_request",
             "description" => "Parameters required by this operation are missing or incorrect.",
             "messages" => %{
               "validation_error" => %{
                 "parameter" => "utxo_pos",
                 "validator" => ":integer"
               }
             }
           } == WatcherHelper.no_success?("utxo.get_exit_data", %{"utxo_pos" => "1200000120000"})
  end

  test "utxo.get_exit_data handles too low utxo position inputs" do
    assert %{
             "object" => "error",
             "code" => "operation:bad_request",
             "description" => "Parameters required by this operation are missing or incorrect.",
             "messages" => %{
               "validation_error" => %{
                 "parameter" => "utxo_pos",
                 "validator" => "{:greater, 0}"
               }
             }
           } = WatcherHelper.no_success?("utxo.get_exit_data", %{"utxo_pos" => 0})
  end
end
