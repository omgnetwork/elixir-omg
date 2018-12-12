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
  use OMG.API.Fixtures

  alias OMG.API
  alias OMG.API.Crypto
  alias OMG.API.TestHelper
  alias OMG.API.Utxo
  alias OMG.Watcher.DB
  alias OMG.Watcher.TestHelper

  require Utxo

  @eth Crypto.zero_address()
  @eth_hex String.duplicate("00", 20)

  @tag fixtures: [:initial_blocks, :carol]
  test "no utxos are returned for non-existing addresses", %{carol: carol} do
    assert [] == get_utxos(carol.addr)
  end

  @tag fixtures: [:initial_blocks, :alice]
  test "utxo from initial blocks are available", %{alice: alice} do
    [
      %{
        "amount" => 1,
        "currency" => @eth_hex,
        "blknum" => 2000,
        "txindex" => 0,
        "oindex" => 1,
        "txbytes" => _txbytes1
      },
      %{
        "amount" => 150,
        "currency" => @eth_hex,
        "blknum" => 3000,
        "txindex" => 0,
        "oindex" => 0,
        "txbytes" => _txbytes2
      },
      %{
        "amount" => 50,
        "currency" => @eth_hex,
        "blknum" => 3000,
        "txindex" => 1,
        "oindex" => 1,
        "txbytes" => _txbytes3
      }
    ] = get_utxos(alice.addr)
  end

  @tag fixtures: [:initial_blocks, :bob, :carol]
  test "spent utxos are moved to new owner", %{bob: bob, carol: carol} do
    [] = get_utxos(carol.addr)

    # bob spends his utxo to carol
    DB.Transaction.update_with(%{
      transactions: [API.TestHelper.create_recovered([{2000, 0, 0, bob}], @eth, [{bob, 49}, {carol, 50}])],
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
               "currency" => "0000000000000000000000000000000000000000"
             }
           ] = get_utxos(carol.addr)
  end

  @tag fixtures: [:initial_blocks, :bob]
  test "unspent deposits are a part of utxo set", %{bob: bob} do
    utxos = get_utxos(bob.addr)

    deposited_utxo = utxos |> Enum.find(&(&1["blknum"] < 1000))

    assert %{
             "amount" => 100,
             "currency" => @eth_hex,
             "blknum" => 2,
             "txindex" => 0,
             "oindex" => 0,
             "txbytes" => nil
           } = deposited_utxo
  end

  @tag fixtures: [:initial_blocks, :alice]
  test "spent deposits are not a part of utxo set", %{alice: alice} do
    assert utxos = get_utxos(alice.addr)

    assert [] = utxos |> Enum.filter(&(&1["blknum"] < 1000))
  end

  @tag fixtures: [:initial_blocks, :carol, :bob]
  test "deposits are spent", %{carol: carol, bob: bob} do
    assert [] = get_utxos(carol.addr)

    assert utxos = get_utxos(bob.addr)

    # bob has 1 unspent deposit
    assert %{
             "amount" => 100,
             "currency" => @eth_hex,
             "blknum" => blknum,
             "txindex" => 0,
             "oindex" => 0
           } = utxos |> Enum.find(&(&1["blknum"] < 1000))

    DB.Transaction.update_with(%{
      transactions: [API.TestHelper.create_recovered([{blknum, 0, 0, bob}], @eth, [{carol, 100}])],
      blknum: 11_000,
      blkhash: <<?#::256>>,
      timestamp: :os.system_time(:second),
      eth_height: 10
    })

    utxos = get_utxos(bob.addr)

    # bob has spent his deposit
    assert [] == utxos |> Enum.filter(&(&1["blknum"] < 1000))

    # carol has new utxo from above tx
    assert [
             %{
               "amount" => 100,
               "currency" => @eth_hex,
               "blknum" => 11_000,
               "txindex" => 0,
               "oindex" => 0
             }
           ] = get_utxos(carol.addr)
  end

  @tag fixtures: [:initial_blocks]
  test "getting exit data returns properly formatted response" do
    utxo_pos = Utxo.position(1000, 1, 0) |> Utxo.Position.encode()

    %{
      "utxo_pos" => _utxo_pos,
      "txbytes" => _txbytes,
      "proof" => proof,
      "sigs" => _sigs
    } = TestHelper.success?("/utxo.get_exit_data", %{"utxo_pos" => utxo_pos})

    assert <<_proof::bytes-size(1024)>> = proof
  end

  @tag fixtures: [:initial_blocks]
  test "getting exit data returns error when there is no txs in specfic block" do
    utxo_pos = Utxo.position(1001, 1, 0) |> Utxo.Position.encode()

    assert %{
             "code" => "exit:invalid",
             "description" => "Utxo was spent or does not exist."
           } = TestHelper.no_success?("/utxo.get_exit_data", %{"utxo_pos" => utxo_pos})
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :alice]
  test "outputs with value zero are not inserted into DB, the other has correct oindex", %{alice: alice} do
    blknum = 11_000

    DB.Transaction.update_with(%{
      transactions: [
        API.TestHelper.create_recovered([], @eth, [{alice, 0}, {alice, 100}]),
        API.TestHelper.create_recovered([], @eth, [{alice, 101}, {alice, 0}])
      ],
      blknum: blknum,
      blkhash: <<?#::256>>,
      timestamp: :os.system_time(:second),
      eth_height: 10
    })

    [
      %{
        "amount" => 100,
        "currency" => @eth_hex,
        "blknum" => ^blknum,
        "txindex" => 0,
        "oindex" => 1,
        "txbytes" => _txbytes2
      },
      %{
        "amount" => 101,
        "currency" => @eth_hex,
        "blknum" => ^blknum,
        "txindex" => 1,
        "oindex" => 0,
        "txbytes" => _txbytes3
      }
    ] = get_utxos(alice.addr)
  end

  defp get_utxos(address) do
    {:ok, address_encode} = Crypto.encode_address(address)
    TestHelper.success?("/utxo.get", %{"address" => address_encode})
  end
end
