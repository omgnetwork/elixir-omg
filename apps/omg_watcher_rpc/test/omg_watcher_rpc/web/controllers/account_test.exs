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

defmodule OMG.WatcherRPC.Web.Controller.AccountTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.WatcherInfo.Fixtures

  import OMG.WatcherInfo.Factory

  alias OMG.Crypto
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias Support.WatcherHelper

  require Utxo

  @eth OMG.Eth.zero_address()
  @payment_output_type OMG.WireFormatTypes.output_type_for(:output_payment_v1)
  @eth_hex @eth |> Encoding.to_hex()
  @other_token <<127::160>>
  @other_token_hex @other_token |> Encoding.to_hex()

  @tag fixtures: [:alice, :bob, :blocks_inserter, :initial_blocks]
  test "Account balance groups account tokens and provide sum of available funds", %{
    blocks_inserter: blocks_inserter,
    alice: alice,
    bob: bob
  } do
    assert [%{"currency" => @eth_hex, "amount" => 349}] == WatcherHelper.success?("account.get_balance", body_for(bob))

    # adds other token funds for alice to make more interesting
    blocks_inserter.([
      {11_000, [OMG.TestHelper.create_recovered([], @other_token, [{alice, 121}, {alice, 256}])]}
    ])

    data = WatcherHelper.success?("account.get_balance", body_for(alice))

    assert [
             %{"currency" => @eth_hex, "amount" => 201},
             %{"currency" => @other_token_hex, "amount" => 377}
           ] == data |> Enum.sort(&(Map.get(&1, "currency") <= Map.get(&2, "currency")))
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "Account balance for non-existing account responds with empty array" do
    no_account = %{addr: <<0::160>>}

    assert [] == WatcherHelper.success?("account.get_balance", body_for(no_account))
  end

  defp body_for(%{addr: address}) do
    %{"address" => Encoding.to_hex(address)}
  end

  @tag fixtures: [:initial_blocks, :alice]
  test "returns last transactions that involve given address", %{
    alice: alice
  } do
    # refer to `/transaction.all` tests for more thorough cases, this is the same
    alice_addr = Encoding.to_hex(alice.addr)

    assert [_] = WatcherHelper.success?("account.get_transactions", %{"address" => alice_addr, "limit" => 1})
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "account.get_balance handles improper type of parameter" do
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
           } == WatcherHelper.no_success?("account.get_balance", %{"address" => 1_234_567_890})
  end

  @tag fixtures: [:alice, :phoenix_ecto_sandbox]
  test "account.get_balance returns bad request error if address is passed as a query parameter", %{
    alice: alice
  } do
    %{"address" => address} = body_for(alice)

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
           } == WatcherHelper.no_success?("account.get_balance?address=#{address}")
  end

  describe "standard_exitable" do
    @tag fixtures: [:phoenix_ecto_sandbox, :db_initialized, :carol]
    test "no utxos are returned for non-existing addresses", %{carol: carol} do
      assert [] == WatcherHelper.get_exitable_utxos(carol.addr)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :db_initialized, :alice, :bob]
    test "get_utxos and get_exitable_utxos have the same return values", %{alice: alice, bob: bob} do
      DB.EthEvent.insert_deposits!([
        %{
          root_chain_txhash: Crypto.hash(<<1000::256>>),
          log_index: 0,
          eth_height: 1,
          owner: alice.addr,
          currency: @eth,
          amount: 333,
          blknum: 1
        }
      ])

      # TODO: this test is brittle because of the way the DB entries are hardcoded
      OMG.DB.multi_update([
        {:put, :utxo,
         {
           {1, 0, 0},
           %{
             output: %{amount: 333, currency: @eth, owner: alice.addr, output_type: @payment_output_type},
             creating_txhash: nil
           }
         }},
        {:put, :utxo,
         {
           {2, 0, 0},
           %{
             output: %{amount: 100, currency: @eth, owner: bob.addr, output_type: @payment_output_type},
             creating_txhash: nil
           }
         }}
      ])

      # utxos contain extra fields such as `spending_txhash` so we compare only the fields we expect from both.
      fields = ["blknum", "txindex", "oindex", "utxo_pos", "amount", "currency", "owner"]

      exitable_utxos =
        alice.addr
        |> WatcherHelper.get_exitable_utxos()
        |> Enum.map(fn utxo -> Map.take(utxo, fields) end)

      utxos =
        alice.addr
        |> WatcherHelper.get_utxos()
        |> Enum.map(fn utxo -> Map.take(utxo, fields) end)

      assert utxos == exitable_utxos
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "account.get_exitable_utxos handles improper type of parameter" do
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
             } == WatcherHelper.no_success?("account.get_exitable_utxos", %{"address" => 1_234_567_890})
    end
  end

  @tag fixtures: [:initial_blocks, :carol]
  test "no utxos are returned for non-existing addresses", %{carol: carol} do
    assert [] == WatcherHelper.get_utxos(carol.addr)
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
           ] = WatcherHelper.get_utxos(alice.addr)
  end

  @tag fixtures: [:initial_blocks, :alice]
  test "encoded utxo positions are delivered", %{alice: alice} do
    [%{"utxo_pos" => utxo_pos, "blknum" => blknum, "txindex" => txindex, "oindex" => oindex} | _] =
      WatcherHelper.get_utxos(alice.addr)

    assert Utxo.position(^blknum, ^txindex, ^oindex) = utxo_pos |> Utxo.Position.decode!()
  end

  @tag fixtures: [:initial_blocks, :bob, :carol]
  test "spent utxos are moved to new owner", %{bob: bob, carol: carol} do
    [] = WatcherHelper.get_utxos(carol.addr)

    # bob spends his utxo to carol
    block_application = %{
      transactions: [OMG.TestHelper.create_recovered([{2000, 0, 0, bob}], @eth, [{bob, 49}, {carol, 50}])],
      number: 11_000,
      hash: <<?#::256>>,
      timestamp: :os.system_time(:second),
      eth_height: 10
    }

    {:ok, _} = DB.Block.insert_from_block_application(block_application)

    assert [
             %{
               "amount" => 50,
               "blknum" => 11_000,
               "txindex" => 0,
               "oindex" => 1,
               "currency" => @eth_hex
             }
           ] = WatcherHelper.get_utxos(carol.addr)
  end

  @tag fixtures: [:initial_blocks, :bob]
  test "unspent deposits are a part of utxo set", %{bob: bob} do
    bob_enc = bob.addr |> Encoding.to_hex()
    deposited_utxo = bob.addr |> WatcherHelper.get_utxos() |> Enum.find(&(&1["blknum"] < 1000))

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
    assert utxos = WatcherHelper.get_utxos(alice.addr)

    assert [] = utxos |> Enum.filter(&(&1["blknum"] < 1000))
  end

  @tag fixtures: [:initial_blocks, :carol, :bob]
  test "deposits are spent", %{carol: carol, bob: bob} do
    assert [] = WatcherHelper.get_utxos(carol.addr)

    assert utxos = WatcherHelper.get_utxos(bob.addr)

    # bob has 1 unspent deposit
    assert %{
             "amount" => 100,
             "currency" => @eth_hex,
             "blknum" => blknum,
             "txindex" => 0,
             "oindex" => 0
           } = utxos |> Enum.find(&(&1["blknum"] < 1000))

    block_application = %{
      transactions: [OMG.TestHelper.create_recovered([{blknum, 0, 0, bob}], @eth, [{carol, 100}])],
      number: 11_000,
      hash: <<?#::256>>,
      timestamp: :os.system_time(:second),
      eth_height: 10
    }

    {:ok, _} = DB.Block.insert_from_block_application(block_application)

    utxos = WatcherHelper.get_utxos(bob.addr)

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
           ] = WatcherHelper.get_utxos(carol.addr)
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "account.get_utxos handles improper type of parameter" do
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
           } == WatcherHelper.no_success?("account.get_utxos", %{"address" => 1_234_567_890})
  end
end
