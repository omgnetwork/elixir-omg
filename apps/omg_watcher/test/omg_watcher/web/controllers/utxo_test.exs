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

defmodule OMG.Watcher.Web.Controller.UtxoTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures

  alias OMG.Utxo
  alias OMG.Watcher.TestHelper
  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @tag fixtures: [:initial_blocks]
  test "getting exit data returns properly formatted response" do
    %{
      "utxo_pos" => _utxo_pos,
      "txbytes" => _txbytes,
      "proof" => proof,
      "sigs" => _sigs
    } = TestHelper.get_exit_data(1000, 1, 0)

    assert <<_proof::bytes-size(512)>> = proof
  end

  @tag fixtures: [:initial_blocks]
  test "getting exit data returns error when there is no txs in specfic block" do
    utxo_pos = Utxo.position(7000, 1, 0) |> Utxo.Position.encode()

    assert %{
             "object" => "error",
             "code" => "exit:invalid",
             "description" => "Utxo was spent or does not exist."
           } = TestHelper.no_success?("utxo.get_exit_data", %{"utxo_pos" => utxo_pos})
  end

  @tag fixtures: [:blocks_inserter, :alice]
  test "outputs with value zero are not inserted into DB, the other has correct oindex", %{
    alice: alice,
    blocks_inserter: blocks_inserter
  } do
    blknum = 11_000

    blocks_inserter.([
      {blknum,
       [
         OMG.TestHelper.create_recovered([], @eth, [{alice, 0}, {alice, 100}]),
         OMG.TestHelper.create_recovered([], @eth, [{alice, 101}, {alice, 0}])
       ]}
    ])

    [
      %{
        "amount" => 100,
        "blknum" => ^blknum,
        "txindex" => 0,
        "oindex" => 1
      },
      %{
        "amount" => 101,
        "blknum" => ^blknum,
        "txindex" => 1,
        "oindex" => 0
      }
    ] = TestHelper.get_utxos(alice.addr) |> Enum.filter(&match?(%{"blknum" => ^blknum}, &1))
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
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
           } == TestHelper.no_success?("utxo.get_exit_data", %{"utxo_pos" => "1200000120000"})
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "utxo.get_exit_data handles too low utxo position inputs" do
    assert %{"object" => "error", "code" => "get_utxo_exit:encoded_utxo_position_too_low"} =
             TestHelper.no_success?("utxo.get_exit_data", %{"utxo_pos" => 1000})
  end
end
