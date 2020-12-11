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

defmodule OMG.WatcherRPC.Web.Controller.ChallengeTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.WatcherInfo.Fixtures

  import OMG.WatcherInfo.Factory

  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias Support.WatcherHelper

  require Utxo

  @eth OMG.Eth.zero_address()

  @tag skip: true
  @tag fixtures: [:phoenix_ecto_sandbox, :alice]
  test "challenge data is properly formatted", %{alice: alice} do
    DB.EthEvent.insert_deposits!([%{owner: alice.addr, currency: @eth, amount: 100, blknum: 1, eth_height: 1}])

    block_application = %{
      transactions: [OMG.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 100}])],
      number: 1000,
      hash: <<?#::256>>,
      timestamp: :os.system_time(:second),
      eth_height: 1
    }

    {:ok, _} = DB.Block.insert_from_block_application(block_application)

    utxo_pos = Utxo.position(1, 0, 0) |> Utxo.Position.encode()

    %{
      "input_index" => _input_index,
      "utxo_pos" => _utxo_pos,
      "sig" => _sig,
      "txbytes" => _txbytes
    } = WatcherHelper.success?("utxo.get_challenge_data", %{"utxo_pos" => utxo_pos})
  end

  @tag skip: true
  @tag fixtures: [:phoenix_ecto_sandbox]
  test "challenging non-existent utxo returns error" do
    utxo_pos = Utxo.position(1, 1, 0) |> Utxo.Position.encode()

    %{
      "code" => "challenge:invalid",
      "description" => "The challenge of particular exit is invalid because provided utxo is not spent"
    } = WatcherHelper.no_success?("utxo.get_challenge_data", %{"utxo_pos" => utxo_pos})
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "utxo.get_challenge_data handles improper type of parameter" do
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
           } == WatcherHelper.no_success?("utxo.get_challenge_data", %{"utxo_pos" => "1200000120000"})
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
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
           } = WatcherHelper.no_success?("utxo.get_challenge_data", %{"utxo_pos" => 0})
  end
end
