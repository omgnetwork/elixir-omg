# Copyright 2018 OmiseGO Pte Ltd
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

  alias OMG.RPC.Web.Encoding
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.Watcher.DB
  alias OMG.Watcher.TestHelper

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @eth_hex Encoding.to_hex(@eth)

  @tag fixtures: [:initial_blocks, :carol]
  test "no utxos are returned for non-existing addresses", %{carol: carol} do
    assert [] == TestHelper.get_utxos(carol.addr)
  end

  @tag fixtures: [:initial_blocks, :alice]
  test "utxo from initial blocks are available", %{alice: alice} do
    alice_enc = alice.addr |> Encoding.to_hex()

    assert [
             %{
               "amount" => 1,
               "currency" => @eth_hex,
               "blknum" => 2000,
               "txindex" => 0,
               "oindex" => 1,
               "owner" => ^alice_enc
             },
             %{
               "amount" => 150,
               "currency" => @eth_hex,
               "blknum" => 3000,
               "txindex" => 0,
               "oindex" => 0,
               "owner" => ^alice_enc
             },
             %{
               "amount" => 50,
               "currency" => @eth_hex,
               "blknum" => 3000,
               "txindex" => 1,
               "oindex" => 1,
               "owner" => ^alice_enc
             }
           ] = TestHelper.get_utxos(alice.addr)
  end

  @tag fixtures: [:initial_blocks, :alice]
  test "encoded utxo positions are delivered", %{alice: alice} do
    [%{"utxo_pos" => utxo_pos, "blknum" => blknum, "txindex" => txindex, "oindex" => oindex} | _] =
      TestHelper.get_utxos(alice.addr)

    assert Utxo.position(^blknum, ^txindex, ^oindex) = utxo_pos |> Utxo.Position.decode()
  end

  @tag fixtures: [:initial_blocks, :bob, :carol]
  test "spent utxos are moved to new owner", %{bob: bob, carol: carol} do
    [] = TestHelper.get_utxos(carol.addr)

    # bob spends his utxo to carol
    DB.Transaction.update_with(%{
      transactions: [OMG.TestHelper.create_recovered([{2000, 0, 0, bob}], @eth, [{bob, 49}, {carol, 50}])],
      blknum: 11_000,
      blkhash: <<?#::256>>,
      timestamp: :os.system_time(:second),
      eth_height: 10
    })

    assert [
             %{
               "amount" => 50,
               "blknum" => 11_000,
               "txindex" => 0,
               "oindex" => 1,
               "currency" => @eth_hex
             }
           ] = TestHelper.get_utxos(carol.addr)
  end

  @tag fixtures: [:initial_blocks, :bob]
  test "unspent deposits are a part of utxo set", %{bob: bob} do
    bob_enc = bob.addr |> Encoding.to_hex()
    deposited_utxo = bob.addr |> TestHelper.get_utxos() |> Enum.find(&(&1["blknum"] < 1000))

    assert %{
             "amount" => 100,
             "currency" => @eth_hex,
             "blknum" => 2,
             "txindex" => 0,
             "oindex" => 0,
             "owner" => ^bob_enc
           } = deposited_utxo
  end

  @tag fixtures: [:initial_blocks, :alice]
  test "spent deposits are not a part of utxo set", %{alice: alice} do
    assert utxos = TestHelper.get_utxos(alice.addr)

    assert [] = utxos |> Enum.filter(&(&1["blknum"] < 1000))
  end

  @tag fixtures: [:initial_blocks, :carol, :bob]
  test "deposits are spent", %{carol: carol, bob: bob} do
    assert [] = TestHelper.get_utxos(carol.addr)

    assert utxos = TestHelper.get_utxos(bob.addr)

    # bob has 1 unspent deposit
    assert %{
             "amount" => 100,
             "currency" => @eth_hex,
             "blknum" => blknum,
             "txindex" => 0,
             "oindex" => 0
           } = utxos |> Enum.find(&(&1["blknum"] < 1000))

    DB.Transaction.update_with(%{
      transactions: [OMG.TestHelper.create_recovered([{blknum, 0, 0, bob}], @eth, [{carol, 100}])],
      blknum: 11_000,
      blkhash: <<?#::256>>,
      timestamp: :os.system_time(:second),
      eth_height: 10
    })

    utxos = TestHelper.get_utxos(bob.addr)

    # bob has spent his deposit
    assert [] == utxos |> Enum.filter(&(&1["blknum"] < 1000))

    carol_enc = carol.addr |> Encoding.to_hex()

    # carol has new utxo from above tx
    assert [
             %{
               "amount" => 100,
               "currency" => @eth_hex,
               "blknum" => 11_000,
               "txindex" => 0,
               "oindex" => 0,
               "owner" => ^carol_enc
             }
           ] = TestHelper.get_utxos(carol.addr)
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "get.utxos handles improper type of parameter" do
    assert %{
             "object" => "error",
             "code" => "operation:bad_request",
             "description" => "Parameters required by this operation are missing or incorrect.",
             "messages" => %{
               "validation_error" => %{
                 "parameter" => "address",
                 "validator" => ":hex"
               }
             }
           } == TestHelper.no_success?("account.get_utxos", %{"address" => 1_234_567_890})
  end

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
end
