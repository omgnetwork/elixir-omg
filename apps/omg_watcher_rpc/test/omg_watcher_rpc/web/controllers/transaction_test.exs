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

defmodule OMG.WatcherRPC.Web.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.Fixtures
  use OMG.WatcherInfo.Fixtures
  use OMG.Watcher.Fixtures

  # only: [build: 1, with_deposit: 1, insert: 1, with_inputs: 2, with_outputs: 2]
  import OMG.WatcherInfo.Factory

  alias OMG.State.Transaction
  alias OMG.TestHelper, as: Test
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Utils.HttpRPC.Response
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.TestServer
  alias OMG.WireFormatTypes
  alias Support.WatcherHelper

  require OMG.State.Transaction.Payment
  import OMG.WatcherInfo.Factory

  require Utxo

  @eth OMG.Eth.zero_address()
  @other_token <<127::160>>
  @eth_hex Encoding.to_hex(@eth)
  @other_token_hex Encoding.to_hex(@other_token)
  @default_data_paging %{"limit" => 200, "page" => 1}
  @tx_type WireFormatTypes.tx_type_for(:tx_payment_v1)
  @str_tx_type Integer.to_string(@tx_type)

  describe "/transaction.get" do
    @tag fixtures: [:initial_blocks]
    test "verifies all inserted transactions available to get", %{initial_blocks: initial_blocks} do
      Enum.each(initial_blocks, fn {blknum, txindex, txhash, _recovered_tx} ->
        txhash_enc = Encoding.to_hex(txhash)

        assert %{"block" => %{"blknum" => ^blknum}, "txhash" => ^txhash_enc, "txindex" => ^txindex} =
                 WatcherHelper.success?("transaction.get", %{id: txhash_enc})
      end)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns transaction in expected format" do
      deposit_1 = with_deposit(build(:txoutput))
      deposit_2 = with_deposit(build(:txoutput))

      input_1 = build(:txoutput)
      input_2 = build(:txoutput)

      output_1 = build(:txoutput)
      output_2 = build(:txoutput)

      creating_transaction =
        insert(:transaction)
        |> with_inputs([deposit_1, deposit_2])
        |> with_outputs([input_1, input_2])

      spending_transaction =
        insert(:transaction)
        |> with_inputs(creating_transaction.outputs)
        |> with_outputs([output_1, output_2])

      expected_response = %{
        "block" => %{
          "blknum" => spending_transaction.block.blknum,
          "eth_height" => spending_transaction.block.eth_height,
          "hash" => Encoding.to_hex(spending_transaction.block.hash),
          "timestamp" => spending_transaction.block.timestamp,
          "tx_count" => spending_transaction.block.tx_count,
          "inserted_at" => Response.serialize(spending_transaction.block.inserted_at).data,
          "updated_at" => Response.serialize(spending_transaction.block.updated_at).data
        },
        "inputs" =>
          Enum.map(spending_transaction.inputs, fn input ->
            %{
              "amount" => input.amount,
              "blknum" => input.blknum,
              "currency" => Encoding.to_hex(input.currency),
              "oindex" => input.oindex,
              "owner" => Encoding.to_hex(input.owner),
              "txindex" => input.txindex,
              "otype" => input.otype,
              "utxo_pos" => Utxo.Position.encode({:utxo_position, input.blknum, input.txindex, input.oindex}),
              "creating_txhash" => to_hex_or_nil(input.creating_txhash),
              "spending_txhash" => to_hex_or_nil(input.spending_txhash),
              "inserted_at" => Response.serialize(input.inserted_at).data,
              "updated_at" => Response.serialize(input.updated_at).data
            }
          end),
        "outputs" =>
          Enum.map(spending_transaction.outputs, fn output ->
            %{
              "amount" => output.amount,
              "blknum" => output.blknum,
              "currency" => Encoding.to_hex(output.currency),
              "oindex" => output.oindex,
              "owner" => Encoding.to_hex(output.owner),
              "txindex" => output.txindex,
              "otype" => output.otype,
              "utxo_pos" => Utxo.Position.encode({:utxo_position, output.blknum, output.txindex, output.oindex}),
              "creating_txhash" => to_hex_or_nil(output.creating_txhash),
              "spending_txhash" => to_hex_or_nil(output.spending_txhash),
              "inserted_at" => Response.serialize(output.inserted_at).data,
              "updated_at" => Response.serialize(output.updated_at).data
            }
          end),
        "txhash" => Encoding.to_hex(spending_transaction.txhash),
        "txbytes" => Encoding.to_hex(spending_transaction.txbytes),
        "txindex" => spending_transaction.txindex,
        "txtype" => spending_transaction.txtype,
        "metadata" => Encoding.to_hex(spending_transaction.metadata),
        "inserted_at" => Response.serialize(spending_transaction.inserted_at).data,
        "updated_at" => Response.serialize(spending_transaction.updated_at).data
      }

      response = WatcherHelper.success?("transaction.get", %{"id" => Encoding.to_hex(spending_transaction.txhash)})

      assert response == expected_response
    end

    @tag fixtures: [:blocks_inserter, :initial_deposits, :alice, :bob]
    test "returns up to 4 inputs / 4 outputs", %{
      blocks_inserter: blocks_inserter,
      alice: alice
    } do
      [_, {_, _, txhash, _recovered_tx}] =
        blocks_inserter.([
          {1000,
           [
             Test.create_recovered(
               [{1, 0, 0, alice}],
               @eth,
               [{alice, 10}, {alice, 20}, {alice, 30}, {alice, 40}]
             ),
             Test.create_recovered(
               [{1000, 0, 0, alice}, {1000, 0, 1, alice}, {1000, 0, 2, alice}, {1000, 0, 3, alice}],
               @eth,
               [{alice, 1}, {alice, 2}, {alice, 3}, {alice, 4}]
             )
           ]}
        ])

      txhash = Encoding.to_hex(txhash)

      assert %{
               "inputs" => [%{"amount" => 10}, %{"amount" => 20}, %{"amount" => 30}, %{"amount" => 40}],
               "outputs" => [%{"amount" => 1}, %{"amount" => 2}, %{"amount" => 3}, %{"amount" => 4}],
               "txhash" => ^txhash,
               "txindex" => 1
             } = WatcherHelper.success?("transaction.get", %{"id" => txhash})
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns error for non existing transaction" do
      txhash = Encoding.to_hex(<<0::256>>)

      assert %{
               "object" => "error",
               "code" => "transaction:not_found",
               "description" => "Transaction doesn't exist for provided search criteria"
             } == WatcherHelper.no_success?("transaction.get", %{"id" => txhash})
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "handles improper length of id parameter" do
      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "id",
                   "validator" => "{:length, 32}"
                 }
               }
             } == WatcherHelper.no_success?("transaction.get", %{"id" => "0x50e901b98fe3389e32d56166a13a88208b03ea75"})
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns bad request error if transaction hash is passed as query parameter" do
      txhash = insert(:transaction) |> Map.get(:txhash) |> Encoding.to_hex()

      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "id",
                   "validator" => ":hex"
                 }
               }
             } == WatcherHelper.no_success?("transaction.get?id=#{txhash}")
    end
  end

  describe "/transaction.all" do
    @tag fixtures: [:initial_blocks]
    test "returns multiple transactions in expected format", %{initial_blocks: initial_blocks} do
      {blknum, txindex, txhash, _recovered_tx} = initial_blocks |> Enum.reverse() |> hd()

      %DB.Block{timestamp: timestamp, eth_height: eth_height, hash: block_hash} = get_block(blknum)
      txhash = Encoding.to_hex(txhash)
      block_hash = Encoding.to_hex(block_hash)

      assert [
               %{
                 "block" => %{
                   "blknum" => ^blknum,
                   "eth_height" => ^eth_height,
                   "hash" => ^block_hash,
                   "timestamp" => ^timestamp
                 },
                 "inputs" => [
                   %{
                     "amount" => _,
                     "blknum" => _,
                     "currency" => _,
                     "oindex" => _,
                     "owner" => _,
                     "txindex" => _,
                     "utxo_pos" => _,
                     "creating_txhash" => _,
                     "spending_txhash" => _
                   }
                   | _
                 ],
                 "outputs" => [
                   %{
                     "amount" => _,
                     "blknum" => _,
                     "currency" => _,
                     "oindex" => _,
                     "owner" => _,
                     "txindex" => _,
                     "utxo_pos" => _,
                     "creating_txhash" => _,
                     "spending_txhash" => _
                   }
                   | _
                 ],
                 "txhash" => ^txhash,
                 "txindex" => ^txindex
               }
               | _
             ] = transaction_all_result()
    end

    @tag fixtures: [:blocks_inserter, :alice]
    test "returns tx from a particular block", %{
      blocks_inserter: blocks_inserter,
      alice: alice
    } do
      blocks_inserter.([
        {1000, [Test.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 300}])]},
        {2000,
         [
           Test.create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 300}]),
           Test.create_recovered([{2000, 1, 0, alice}], @eth, [{alice, 300}])
         ]}
      ])

      assert [%{"block" => %{"blknum" => 2000}, "txindex" => 1}, %{"block" => %{"blknum" => 2000}, "txindex" => 0}] =
               transaction_all_result(%{"blknum" => 2000})

      assert [] = transaction_all_result(%{"blknum" => 3000})
    end

    @tag fixtures: [:blocks_inserter, :alice, :bob]
    test "returns tx from a particular block that contains requested address as the sender", %{
      blocks_inserter: blocks_inserter,
      alice: alice,
      bob: bob
    } do
      blocks_inserter.([
        {1000, [Test.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 300}])]},
        {2000,
         [
           Test.create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 300}]),
           Test.create_recovered([{2, 0, 0, bob}], @eth, [{bob, 300}])
         ]}
      ])

      address = Encoding.to_hex(bob.addr)

      assert [%{"block" => %{"blknum" => 2000}, "txindex" => 1}] =
               transaction_all_result(%{"address" => address, "blknum" => 2000})
    end

    @tag fixtures: [:blocks_inserter, :initial_deposits, :alice, :bob]
    test "returns tx that contains requested address as the sender and not recipient", %{
      blocks_inserter: blocks_inserter,
      alice: alice,
      bob: bob
    } do
      blocks_inserter.([
        {1000,
         [
           Test.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}])
         ]}
      ])

      address = Encoding.to_hex(alice.addr)

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] = transaction_all_result(%{"address" => address})
    end

    @tag fixtures: [:blocks_inserter, :initial_deposits, :alice, :bob, :carol]
    test "returns only and all txs that match the address filtered", %{
      blocks_inserter: blocks_inserter,
      alice: alice,
      bob: bob,
      carol: carol
    } do
      blocks_inserter.([
        {1000,
         [
           Test.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}]),
           Test.create_recovered([{2, 0, 0, bob}], @eth, [{bob, 300}]),
           Test.create_recovered([{1000, 1, 0, bob}], @eth, [{alice, 300}])
         ]}
      ])

      alice_addr = Encoding.to_hex(alice.addr)
      carol_addr = Encoding.to_hex(carol.addr)

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 2}, %{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               transaction_all_result(%{"address" => alice_addr})

      assert [] = transaction_all_result(%{"address" => carol_addr})
    end

    @tag fixtures: [:blocks_inserter, :alice, :bob]
    test "returns tx that contains requested address as the recipient and not sender", %{
      blocks_inserter: blocks_inserter,
      alice: alice,
      bob: bob
    } do
      blocks_inserter.([
        {1000,
         [
           Test.create_recovered([{2, 0, 0, bob}], @eth, [{alice, 100}])
         ]}
      ])

      address = Encoding.to_hex(alice.addr)

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] = transaction_all_result(%{"address" => address})
    end

    @tag fixtures: [:blocks_inserter, :alice]
    test "returns tx that contains requested address as both sender & recipient is listed once", %{
      blocks_inserter: blocks_inserter,
      alice: alice
    } do
      blocks_inserter.([
        {1000,
         [
           Test.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 100}])
         ]}
      ])

      address = Encoding.to_hex(alice.addr)

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] = transaction_all_result(%{"address" => address})
    end

    @tag fixtures: [:blocks_inserter, :alice]
    test "returns tx without inputs and contains requested address as recipient", %{
      blocks_inserter: blocks_inserter,
      alice: alice
    } do
      blocks_inserter.([
        {1000,
         [
           Test.create_recovered([], @eth, [{alice, 10}])
         ]}
      ])

      address = Encoding.to_hex(alice.addr)

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] = transaction_all_result(%{"address" => address})
    end

    @tag fixtures: [:initial_blocks]
    test "returns transactions containing metadata", %{initial_blocks: initial_blocks} do
      {blknum, txindex, txhash, recovered_tx} = Enum.find(initial_blocks, &match?({2000, 0, _, _}, &1))

      expected_metadata = Encoding.to_hex(recovered_tx.signed_tx.raw_tx.metadata)
      expected_txhash = Encoding.to_hex(txhash)

      assert [
               %{
                 "block" => %{"blknum" => ^blknum},
                 "metadata" => ^expected_metadata,
                 "txhash" => ^expected_txhash,
                 "txindex" => ^txindex
               }
             ] = transaction_all_result(%{"metadata" => expected_metadata})
    end

    @tag fixtures: [:blocks_inserter, :initial_deposits, :alice]
    test "returns transactions with matching txtype", %{
      blocks_inserter: blocks_inserter,
      alice: alice
    } do
      blocks_inserter.([
        {1000,
         [
           Test.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 300}]),
           Test.create_recovered([{2, 0, 0, alice}], @eth, [{alice, 300}]),
           Test.create_recovered([{1000, 1, 0, alice}], @eth, [{alice, 300}]),
           Test.create_recovered_fee_tx(1000, alice.addr, @eth, 5)
         ]}
      ])

      assert [%{"txindex" => 2}, %{"txindex" => 1}, %{"txindex" => 0}] = transaction_all_result(%{"txtypes" => [1]})
      assert [%{"txindex" => 3}] = transaction_all_result(%{"txtypes" => [3]})

      assert [%{"txindex" => 3}, %{"txindex" => 2}, %{"txindex" => 1}, %{"txindex" => 0}] =
               transaction_all_result(%{"txtypes" => [1, 3]})

      assert [%{"txindex" => 3}, %{"txindex" => 2}, %{"txindex" => 1}, %{"txindex" => 0}] =
               transaction_all_result(%{"txtypes" => []})
    end
  end

  describe "/transaction.all pagination" do
    @tag fixtures: [:alice, :bob, :initial_deposits, :blocks_inserter]
    test "returns list of transactions limited by address", %{
      blocks_inserter: blocks_inserter,
      alice: alice,
      bob: bob
    } do
      blocks_inserter.([
        {1000,
         [
           Test.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 3}]),
           Test.create_recovered([{1_000, 0, 0, bob}], @eth, [{bob, 2}])
         ]},
        {2000,
         [
           Test.create_recovered([{1_000, 1, 0, bob}], @eth, [{alice, 1}])
         ]}
      ])

      alice_addr = Encoding.to_hex(alice.addr)

      assert {
               [%{"block" => %{"blknum" => 2000}, "txindex" => 0}, %{"block" => %{"blknum" => 1000}, "txindex" => 1}],
               %{"limit" => 2, "page" => 1}
             } = transaction_all_with_paging(%{limit: 2})

      assert {[%{"block" => %{"blknum" => 2000}, "txindex" => 0}, %{"block" => %{"blknum" => 1000}, "txindex" => 0}],
              %{"limit" => 2, "page" => 1}} = transaction_all_with_paging(%{address: alice_addr, limit: 2})

      bob_addr = Encoding.to_hex(bob.addr)

      assert {[%{"block" => %{"blknum" => 1000}, "txindex" => 0}], %{"limit" => 2, "page" => 2}} =
               transaction_all_with_paging(%{address: bob_addr, limit: 2, page: 2})
    end

    @tag fixtures: [:initial_blocks]
    test "returns list of transactions limited by block number" do
      assert {[%{"block" => %{"blknum" => 1000}, "txindex" => 1}], %{"limit" => 1, "page" => 1}} =
               transaction_all_with_paging(%{blknum: 1000, limit: 1, page: 1})

      assert {[%{"block" => %{"blknum" => 1000}, "txindex" => 0}], %{"limit" => 1, "page" => 2}} =
               transaction_all_with_paging(%{blknum: 1000, limit: 1, page: 2})

      assert {[], %{"limit" => 1, "page" => 3}} = transaction_all_with_paging(%{blknum: 1000, limit: 1, page: 3})
    end

    @tag fixtures: [:initial_blocks]
    test "limiting all transactions without address filter" do
      assert {[
                %{"block" => %{"blknum" => 3000}, "txindex" => 1} = tx1,
                %{"block" => %{"blknum" => 3000}, "txindex" => 0} = tx2
              ], %{"limit" => 2, "page" => 1}} = transaction_all_with_paging(%{limit: 2})

      assert {[^tx1, ^tx2], %{"limit" => 2, "page" => 1}} = transaction_all_with_paging(%{limit: 2, page: 1})

      assert {[%{"block" => %{"blknum" => 2000}, "txindex" => 0}, %{"block" => %{"blknum" => 1000}, "txindex" => 1}],
              %{"limit" => 2, "page" => 2}} = transaction_all_with_paging(%{limit: 2, page: 2})

      assert {[%{"block" => %{"blknum" => 1000}, "txindex" => 0}], %{"limit" => 2, "page" => 3}} =
               transaction_all_with_paging(%{limit: 2, page: 3})
    end

    @tag fixtures: [:alice, :bob, :initial_deposits, :blocks_inserter]
    test "pagination is unstable - client libs needs to remove duplicates", %{
      blocks_inserter: blocks_inserter,
      alice: alice,
      bob: bob
    } do
      blocks_inserter.([
        {1000,
         [
           Test.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 3}]),
           Test.create_recovered([{1_000, 0, 0, bob}], @eth, [{bob, 2}])
         ]}
      ])

      assert {[
                %{"block" => %{"blknum" => 1000}, "txindex" => 1} = tx1,
                %{"block" => %{"blknum" => 1000}, "txindex" => 0} = tx2
              ], %{"limit" => 2, "page" => 1}} = transaction_all_with_paging(%{limit: 2})

      # After 2 txs were requested 2 more was added, so then asking for the next page, the same
      # already seen transaction will be returned. This test shows the limitation of current implementation.
      blocks_inserter.([
        {2000,
         [
           Test.create_recovered([{5, 0, 0, alice}], @eth, [{bob, 10}]),
           Test.create_recovered([{1_002, 0, 0, bob}], @eth, [{alice, 5}])
         ]}
      ])

      assert {[^tx1, ^tx2], %{"limit" => 2, "page" => 2}} = transaction_all_with_paging(%{limit: 2, page: 2})
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "handles improper limit parameter" do
      invalid_limit = "50"

      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "limit",
                   "validator" => ":integer"
                 }
               }
             } ==
               WatcherHelper.no_success?("transaction.all", %{"limit" => invalid_limit})
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "handles improper address parameter" do
      too_short_address = "0x" <> String.duplicate("00", 19)

      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "address",
                   "validator" => "{:length, 20}"
                 }
               }
             } ==
               WatcherHelper.no_success?("transaction.all", %{"address" => too_short_address})
    end
  end

  defp transaction_all_with_paging(body) do
    %{
      "success" => true,
      "data" => data,
      "data_paging" => paging
    } = WatcherHelper.rpc_call("transaction.all", body, 200)

    {data, paging}
  end

  defp transaction_all_result(body \\ nil) do
    {result, paging} = transaction_all_with_paging(body)

    assert @default_data_paging == paging

    result
  end

  describe "/transaction.submit with binary-encoded transaction" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "handles incorrectly encoded parameter" do
      hex_without_0x = "5df13a6bf96dbcf6e66d8babd6b55bd40d64d4320c3b115364c6588fc18c2a21"

      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "transaction",
                   "validator" => ":hex"
                 }
               }
             } == WatcherHelper.no_success?("transaction.submit", %{"transaction" => hex_without_0x})
    end

    @tag fixtures: [:alice, :phoenix_ecto_sandbox]
    test "provides stateless validation", %{alice: alice} do
      signed_bytes = Test.create_encoded([{1, 0, 0, alice}, {1, 0, 0, alice}], @eth, [{alice, 100}])

      assert %{
               "code" => "submit:duplicate_inputs",
               "description" => nil,
               "object" => "error"
             } == WatcherHelper.no_success?("transaction.submit", %{"transaction" => Encoding.to_hex(signed_bytes)})
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "does not accept fee transactions", %{alice: alice} do
      fee_tx =
        Transaction.Fee.new(1000, {alice.addr, @eth, 1551})
        |> Test.sign_encode([])
        |> Encoding.to_hex()

      assert %{
               "code" => "submit:transaction_not_supported",
               "description" => _,
               "object" => "error"
             } =
               WatcherHelper.no_success?("transaction.submit", %{
                 "transaction" => fee_tx
               })
    end
  end

  describe "/transaction.submit with structural transaction" do
    deffixture typed_data_request(alice, bob) do
      contract_addr = Application.fetch_env!(:omg_eth, :contract_addr)
      alice_addr = Encoding.to_hex(alice.addr)
      bob_addr = Encoding.to_hex(bob.addr)

      %{
        # these values should match configuration :omg, :eip_712_domain
        "domain" => %{
          "name" => "OMG Network",
          "version" => "1",
          "salt" => "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
          "verifyingContract" => contract_addr.plasma_framework
        },
        "message" => %{
          "input0" => %{"blknum" => 1000, "txindex" => 0, "oindex" => 1},
          "input1" => %{"blknum" => 3001, "txindex" => 0, "oindex" => 0},
          "input2" => %{"blknum" => 0, "txindex" => 0, "oindex" => 0},
          "input3" => %{"blknum" => 0, "txindex" => 0, "oindex" => 0},
          "output0" => %{"owner" => alice_addr, "currency" => @eth_hex, "amount" => 10},
          "output1" => %{"owner" => alice_addr, "currency" => @other_token_hex, "amount" => 300},
          "output2" => %{"owner" => bob_addr, "currency" => @other_token_hex, "amount" => 100},
          "output3" => %{"owner" => @eth_hex, "currency" => @eth_hex, "amount" => 0},
          "metadata" => Encoding.to_hex(<<0::256>>)
        },
        "signatures" => <<127::520>> |> List.duplicate(2) |> Enum.map(&Encoding.to_hex/1)
      }
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :typed_data_request]
    test "ensures all required fields are passed", %{typed_data_request: typed_data_request} do
      req_without_domain = Map.drop(typed_data_request, ["domain"])

      assert %{
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "object" => "error",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "domain",
                   "validator" => ":map"
                 }
               }
             } == WatcherHelper.no_success?("transaction.submit_typed", req_without_domain)

      req_without_message = Map.drop(typed_data_request, ["message"])

      assert %{
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "object" => "error",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "message",
                   "validator" => ":map"
                 }
               }
             } == WatcherHelper.no_success?("transaction.submit_typed", req_without_message)

      req_without_sigs = Map.drop(typed_data_request, ["signatures"])

      assert %{
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "object" => "error",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "signatures",
                   "validator" => ":list"
                 }
               }
             } == WatcherHelper.no_success?("transaction.submit_typed", req_without_sigs)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :typed_data_request]
    test "input & sigs count should match", %{typed_data_request: typed_data_request} do
      # Providing 2 non-zero inputs & 1 signature
      too_little_sigs = Map.update!(typed_data_request, "signatures", fn sigs -> Enum.take(sigs, 1) end)

      assert %{
               "code" => "submit_typed:missing_signature",
               "description" =>
                 "Signatures should correspond to inputs owner. When all non-empty inputs has the same owner, " <>
                   "signatures should be duplicated.",
               "object" => "error"
             } == WatcherHelper.no_success?("transaction.submit_typed", too_little_sigs)

      # Providing 2 non-zero inputs & 4 signatures
      too_many_sigs = Map.update!(typed_data_request, "signatures", fn sigs -> sigs ++ sigs end)

      assert %{
               "code" => "submit_typed:superfluous_signature",
               "description" =>
                 "Number of non-empty inputs should match signatures count. Remove redundant signatures.",
               "object" => "error"
             } == WatcherHelper.no_success?("transaction.submit_typed", too_many_sigs)
    end
  end

  describe "/transaction.create" do
    setup tags do
      context = TestServer.start()
      on_exit(fn -> TestServer.stop(context) end)
      Map.put(tags, :test_server, context)
    end

    @default_fee_amount 5
    @default_fee_currency @eth_hex
    @fee_response %{
      @str_tx_type => [
        %{
          "currency" => @default_fee_currency,
          "amount" => @default_fee_amount,
          "subunit_to_unit" => 1_000_000_000_000_000_000,
          "pegged_amount" => 4,
          "pegged_currency" => "USD",
          "pegged_subunit_to_unit" => 100,
          "updated_at" => "2019-01-01T10:10:00+00:00"
        }
      ]
    }
    deffixture more_utxos(alice, blocks_inserter) do
      blocks_inserter.([
        {5000,
         [
           Test.create_recovered([], @eth, [{alice, 40}, {alice, 42}, {alice, 43}, {alice, 44}]),
           Test.create_recovered([], @eth, [{alice, 41}, {alice, 45}]),
           Test.create_recovered([], @other_token, [{alice, 5}, {alice, 110}, {alice, 15}]),
           Test.create_recovered([], @other_token, [{alice, 105}, {alice, 10}, {alice, 115}])
         ]}
      ])
    end

    @tag fixtures: [:alice, :bob, :more_utxos]
    test "returns appropriate schema", %{alice: alice, bob: bob, more_utxos: inserted_txs, test_server: context} do
      alias OMG.Utxo
      require Utxo
      prepare_test_server(context, @fee_response)
      alice_to_bob = 100
      metadata = (alice.addr <> bob.addr) |> OMG.Crypto.hash() |> Encoding.to_hex()

      alice_addr = Encoding.to_hex(alice.addr)
      bob_addr = Encoding.to_hex(bob.addr)
      blknum = 5000
      creating_txhash = inserted_txs |> Enum.at(0) |> elem(2) |> Encoding.to_hex()

      assert %{
               "transactions" => [
                 %{
                   "inputs" => [
                     %{
                       "owner" => ^alice_addr,
                       "currency" => @eth_hex,
                       "blknum" => ^blknum,
                       "txindex" => txindex,
                       "oindex" => oindex,
                       "utxo_pos" => utxo_pos,
                       "creating_txhash" => ^creating_txhash,
                       "spending_txhash" => nil
                     }
                     | _
                   ],
                   "outputs" => [
                     %{"amount" => ^alice_to_bob, "currency" => @eth_hex, "owner" => ^bob_addr},
                     %{"currency" => @eth_hex, "owner" => ^alice_addr, "amount" => _rest}
                   ],
                   "metadata" => ^metadata,
                   "fee" => %{"amount" => @default_fee_amount, "currency" => @default_fee_currency},
                   "txbytes" => "0x" <> _txbytes,
                   "sign_hash" => "0x" <> _hash
                 }
               ]
             } =
               WatcherHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => alice_addr,
                   "payments" => [
                     %{"amount" => alice_to_bob, "currency" => @eth_hex, "owner" => bob_addr}
                   ],
                   "fee" => %{"currency" => @default_fee_currency},
                   "metadata" => metadata
                 }
               )

      assert Utxo.Position.encode(Utxo.position(blknum, txindex, oindex)) == utxo_pos
    end

    @tag fixtures: [:alice, :bob, :more_utxos]
    test "returns correctly formed transaction, identical with the verbose form", %{
      alice: alice,
      bob: bob,
      test_server: context
    } do
      alias OMG.State.Transaction

      prepare_test_server(context, @fee_response)

      assert %{
               "transactions" => [
                 %{
                   "inputs" => verbose_inputs,
                   "outputs" => verbose_outputs,
                   "metadata" => verbose_metadata,
                   "txbytes" => tx_hex,
                   "sign_hash" => sign_hash_hex
                 }
               ]
             } =
               WatcherHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [%{"amount" => 100, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)}],
                   "fee" => %{"currency" => @default_fee_currency},
                   "metadata" => Encoding.to_hex(<<123::256>>)
                 }
               )

      verbose_tx =
        Transaction.Payment.new(
          Enum.map(verbose_inputs, &{&1["blknum"], &1["txindex"], &1["oindex"]}),
          Enum.map(verbose_outputs, &{from_hex!(&1["owner"]), from_hex!(&1["currency"]), &1["amount"]}),
          from_hex!(verbose_metadata)
        )

      assert tx_hex == verbose_tx |> Transaction.raw_txbytes() |> Encoding.to_hex()
      assert sign_hash_hex == verbose_tx |> OMG.TypedDataHash.hash_struct() |> Encoding.to_hex()
    end

    @tag fixtures: [:alice, :bob, :more_utxos]
    test "returns typed data in the form of request of typedDataSign", %{alice: alice, bob: bob, test_server: context} do
      alias OMG.State.Transaction

      metadata_hex = Encoding.to_hex(<<123::256>>)
      prepare_test_server(context, @fee_response)

      assert %{
               "transactions" => [
                 %{
                   "typed_data" => %{
                     "primaryType" => "Transaction",
                     "types" => %{
                       "EIP712Domain" => [%{"name" => "name"} | _],
                       "Transaction" => [_ | _],
                       "Input" => [_ | _],
                       "Output" => [_ | _]
                     },
                     "domain" => %{
                       "name" => "OMG Network",
                       "verifyingContract" => "0x" <> _contract
                     },
                     "message" => %{
                       "input0" => %{"blknum" => _, "txindex" => _, "oindex" => _},
                       "output0" => %{"owner" => "0x" <> _, "currency" => @eth_hex, "amount" => _},
                       "metadata" => ^metadata_hex
                     }
                   }
                 }
               ]
             } =
               WatcherHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [%{"amount" => 100, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)}],
                   "fee" => %{"currency" => @default_fee_currency},
                   "metadata" => metadata_hex
                 }
               )
    end

    @tag fixtures: [:alice, :bob, :more_utxos, :blocks_inserter]
    test "allows to pay single token tx", %{
      alice: alice,
      bob: bob,
      blocks_inserter: blocks_inserter,
      test_server: context
    } do
      alice_balance = balance_in_token(alice.addr, @eth)
      bob_balance = balance_in_token(bob.addr, @eth)

      payment = 100

      prepare_test_server(context, @fee_response)

      assert %{
               "transactions" => [%{"txbytes" => tx_hex}]
             } =
               WatcherHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => payment, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)}
                   ],
                   "fee" => %{"currency" => @default_fee_currency}
                 }
               )

      make_payments(7000, alice, [tx_hex], blocks_inserter)

      assert alice_balance - (payment + @default_fee_amount) == balance_in_token(alice.addr, @eth)
      assert bob_balance + payment == balance_in_token(bob.addr, @eth)
    end

    @tag fixtures: [:alice, :bob, :more_utxos, :blocks_inserter]
    test "allows to pay multi token tx", %{
      alice: alice,
      bob: bob,
      blocks_inserter: blocks_inserter,
      test_server: context
    } do
      alice_eth = balance_in_token(alice.addr, @eth)
      alice_token = balance_in_token(alice.addr, @other_token)
      bob_eth = balance_in_token(bob.addr, @eth)
      bob_token = balance_in_token(bob.addr, @other_token)

      payment_eth = 100
      payment_token = 110

      prepare_test_server(context, @fee_response)

      assert %{
               "transactions" => [%{"txbytes" => tx_hex}]
             } =
               WatcherHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => payment_eth, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)},
                     %{"amount" => payment_token, "currency" => @other_token_hex, "owner" => Encoding.to_hex(bob.addr)}
                   ],
                   "fee" => %{"currency" => @default_fee_currency}
                 }
               )

      make_payments(7000, alice, [tx_hex], blocks_inserter)

      assert alice_eth - (payment_eth + @default_fee_amount) == balance_in_token(alice.addr, @eth)
      assert alice_token - payment_token == balance_in_token(alice.addr, @other_token)
      assert bob_eth + payment_eth == balance_in_token(bob.addr, @eth)
      assert bob_token + payment_token == balance_in_token(bob.addr, @other_token)
    end

    @tag fixtures: [:alice, :bob, :more_utxos, :blocks_inserter]
    test "allows to pay other token tx with fee in different currency",
         %{alice: alice, bob: bob, blocks_inserter: blocks_inserter, test_server: context} do
      alice_eth = balance_in_token(alice.addr, @eth)
      alice_token = balance_in_token(alice.addr, @other_token)
      bob_token = balance_in_token(bob.addr, @other_token)

      payment_token = 110

      prepare_test_server(context, @fee_response)

      assert %{
               "transactions" => [%{"txbytes" => tx_hex}]
             } =
               WatcherHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => payment_token, "currency" => @other_token_hex, "owner" => Encoding.to_hex(bob.addr)}
                   ],
                   "fee" => %{"currency" => @default_fee_currency}
                 }
               )

      make_payments(7000, alice, [tx_hex], blocks_inserter)

      assert alice_eth - @default_fee_amount == balance_in_token(alice.addr, @eth)
      assert alice_token - payment_token == balance_in_token(alice.addr, @other_token)
      assert bob_token + payment_token == balance_in_token(bob.addr, @other_token)
    end

    @tag fixtures: [:alice, :bob, :more_utxos]
    test "insufficient funds returns custom error", %{alice: alice, bob: bob, test_server: context} do
      balance = balance_in_token(alice.addr, @eth)
      payment = balance + 10

      prepare_test_server(context, @fee_response)

      assert %{
               "object" => "error",
               "code" => "transaction.create:insufficient_funds",
               "description" => "Account balance is too low to satisfy the payment.",
               "messages" => [%{"token" => @eth_hex, "missing" => payment + @default_fee_amount - balance}]
             } ==
               WatcherHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => payment, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)}
                   ],
                   "fee" => %{"currency" => @default_fee_currency}
                 }
               )
    end

    @tag fixtures: [:alice, :bob, :more_utxos]
    test "unknown owner returns insufficient funds error", %{alice: alice, bob: bob, test_server: context} do
      assert 0 == balance_in_token(bob.addr, @eth)
      payment = 25

      prepare_test_server(context, @fee_response)

      assert %{
               "object" => "error",
               "code" => "transaction.create:insufficient_funds",
               "description" => "Account balance is too low to satisfy the payment.",
               "messages" => [%{"token" => @eth_hex, "missing" => payment + @default_fee_amount}]
             } ==
               WatcherHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(bob.addr),
                   "payments" => [
                     %{"amount" => payment, "currency" => @eth_hex, "owner" => Encoding.to_hex(alice.addr)}
                   ],
                   "fee" => %{"currency" => @default_fee_currency}
                 }
               )
    end

    @tag fixtures: [:alice, :more_utxos, :blocks_inserter]
    test "does not return txbytes when spend owner is not provided", %{alice: alice, test_server: context} do
      payment = 100
      alice_addr = Encoding.to_hex(alice.addr)

      prepare_test_server(context, @fee_response)

      assert %{
               "transactions" => [
                 %{
                   "txbytes" => nil,
                   "outputs" => [
                     %{"amount" => ^payment, "currency" => @eth_hex, "owner" => nil},
                     %{"currency" => @eth_hex, "owner" => ^alice_addr}
                   ]
                 }
               ]
             } =
               WatcherHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => payment, "currency" => @eth_hex}
                   ],
                   "fee" => %{"currency" => @default_fee_currency}
                 }
               )
    end

    @tag fixtures: [:alice, :bob, :more_utxos]
    test "total number of outputs exceeds allowed outputs returns custom error", %{
      alice: alice,
      bob: bob,
      test_server: context
    } do
      bob_addr = Encoding.to_hex(bob.addr)

      prepare_test_server(context, @fee_response)

      assert %{
               "object" => "error",
               "code" => "transaction.create:too_many_outputs",
               "description" => "Total number of payments + change + fees exceed maximum allowed outputs."
             } ==
               WatcherHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => 1, "currency" => @other_token_hex, "owner" => bob_addr},
                     %{"amount" => 2, "currency" => @other_token_hex, "owner" => bob_addr},
                     %{"amount" => 3, "currency" => @other_token_hex, "owner" => bob_addr}
                   ],
                   "fee" => %{"currency" => @default_fee_currency}
                 }
               )
    end

    @tag fixtures: [:alice, :more_utxos]
    test "transaction without payments that burns funds in fees is created correctly and incorrect on decoding",
         %{alice: alice, test_server: context} do
      prepare_test_server(context, %{
        @str_tx_type => [
          %{
            "currency" => @other_token_hex,
            "amount" => @default_fee_amount,
            "subunit_to_unit" => 1_000_000_000_000_000_000,
            "pegged_amount" => 4,
            "pegged_currency" => "USD",
            "pegged_subunit_to_unit" => 100,
            "updated_at" => "2019-01-01T10:10:00+00:00"
          }
        ]
      })

      assert %{
               "transactions" => [%{"txbytes" => tx_hex}]
             } =
               WatcherHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [],
                   "fee" => %{"currency" => @other_token_hex}
                 }
               )

      assert {:error, :empty_outputs} = tx_hex |> from_hex!() |> Transaction.decode()
    end

    @tag fixtures: [:alice, :more_utxos]
    test "empty transaction without payments list is not allowed", %{alice: alice, test_server: context} do
      alice_addr = Encoding.to_hex(alice.addr)

      prepare_test_server(context, %{
        @str_tx_type => [
          %{
            "currency" => @default_fee_currency,
            "amount" => 0,
            "subunit_to_unit" => 1_000_000_000_000_000_000,
            "pegged_amount" => 4,
            "pegged_currency" => "USD",
            "pegged_subunit_to_unit" => 100,
            "updated_at" => "2019-01-01T10:10:00+00:00"
          }
        ]
      })

      assert %{
               "object" => "error",
               "code" => "transaction.create:empty_transaction",
               "description" => "Requested payment transfers no funds."
             } ==
               WatcherHelper.no_success?(
                 "transaction.create",
                 %{"owner" => alice_addr, "payments" => [], "fee" => %{"currency" => @default_fee_currency}}
               )
    end

    @tag fixtures: [:alice, :more_utxos]
    test "returns an error when requester is equal to all the outputs owner", %{alice: alice} do
      params = %{
        "owner" => Encoding.to_hex(alice.addr),
        "payments" => [
          %{"amount" => 1, "currency" => @eth_hex, "owner" => Encoding.to_hex(alice.addr)},
          %{"amount" => 1, "currency" => @eth_hex, "owner" => Encoding.to_hex(alice.addr)}
        ],
        "fee" => %{"currency" => @default_fee_currency}
      }

      assert %{
               "object" => "error",
               "code" => "transaction.create:self_transaction_not_supported",
               "description" => "This endpoint cannot be used to create merge or split transactions."
             } == WatcherHelper.no_success?("transaction.create", params)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
    test "returns an error when need more than 4 inputs to satisfy payments and fee", %{
      alice: alice,
      bob: bob,
      test_server: context
    } do
      prepare_test_server(context, @fee_response)

      _ = insert(:txoutput, amount: 100, currency: @eth, owner: alice.addr)
      _ = insert(:txoutput, amount: 100, currency: @eth, owner: alice.addr)
      _ = insert(:txoutput, amount: 100, currency: @eth, owner: alice.addr)
      _ = insert(:txoutput, amount: 100, currency: @eth, owner: alice.addr)
      _ = insert(:txoutput, amount: 100, currency: @eth, owner: alice.addr)

      params = %{
        "owner" => Encoding.to_hex(alice.addr),
        "payments" => [
          %{"amount" => 495, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)}
        ],
        "fee" => %{"currency" => @eth_hex}
      }

      assert %{
               "code" => "transaction.create:too_many_inputs",
               "description" =>
                 "The number of inputs required to cover the payment and fee exceeds the maximum allowed.",
               "object" => "error"
             } == WatcherHelper.no_success?("transaction.create", params)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
    test "stealth add inputs when 2 inputs use different currencies", %{
      alice: alice,
      bob: bob,
      test_server: context
    } do
      prepare_test_server(context, @fee_response)

      _ = insert(:txoutput, amount: 5, currency: @eth, owner: alice.addr)
      _ = insert(:txoutput, amount: 20, currency: @other_token, owner: alice.addr)
      _ = insert(:txoutput, amount: 30, currency: @other_token, owner: alice.addr)
      _ = insert(:txoutput, amount: 40, currency: @other_token, owner: alice.addr)

      params = %{
        "owner" => Encoding.to_hex(alice.addr),
        "payments" => [
          %{"amount" => 20, "currency" => @other_token_hex, "owner" => Encoding.to_hex(bob.addr)}
        ],
        "fee" => %{"currency" => @eth_hex}
      }

      assert %{
               "transactions" => [
                 %{
                   "fee" => %{
                     "amount" => 5,
                     "currency" => @eth_hex
                   },
                   "inputs" => [
                     %{"amount" => 5, "currency" => @eth_hex},
                     %{"amount" => 40, "currency" => @other_token_hex},
                     %{"amount" => 30, "currency" => @other_token_hex},
                     %{"amount" => 20, "currency" => @other_token_hex}
                   ]
                 }
               ]
             } = WatcherHelper.success?("transaction.create", params)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
    test "stealth add inputs when 2 inputs can matched payments and fees", %{
      alice: alice,
      bob: bob,
      test_server: context
    } do
      prepare_test_server(context, @fee_response)

      _ = insert(:txoutput, amount: 10, currency: @eth, owner: alice.addr)
      _ = insert(:txoutput, amount: 20, currency: @eth, owner: alice.addr)
      _ = insert(:txoutput, amount: 30, currency: @eth, owner: alice.addr)
      _ = insert(:txoutput, amount: 40, currency: @eth, owner: alice.addr)

      params = %{
        "owner" => Encoding.to_hex(alice.addr),
        "payments" => [
          %{"amount" => 45, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)}
        ],
        "fee" => %{"currency" => @eth_hex}
      }

      assert %{
               "transactions" => [
                 %{
                   "fee" => %{
                     "amount" => 5,
                     "currency" => @eth_hex
                   },
                   "inputs" => [
                     %{"amount" => 20},
                     %{"amount" => 10},
                     %{"amount" => 30},
                     %{"amount" => 40}
                   ]
                 }
               ]
             } = WatcherHelper.success?("transaction.create", params)
    end

    defp balance_in_token(address, token) do
      currency = Encoding.to_hex(token)

      Enum.find_value(WatcherHelper.get_balance(address), 0, fn
        %{"currency" => ^currency, "amount" => amount} -> amount
        _ -> false
      end)
    end

    defp make_payments(blknum, spender, txs_bytes, blocks_inserter) when is_list(txs_bytes) do
      alias OMG.DevCrypto
      alias OMG.State.Transaction

      recovered_txs =
        Enum.map(txs_bytes, fn "0x" <> tx ->
          raw_tx = tx |> Base.decode16!(case: :lower) |> Transaction.decode!()
          n_inputs = raw_tx |> Transaction.get_inputs() |> length

          raw_tx
          |> DevCrypto.sign(List.duplicate(spender.priv, n_inputs))
          |> Transaction.Signed.encode()
          |> Transaction.Recovered.recover_from!()
        end)

      blocks_inserter.([{blknum, recovered_txs}])
    end

    defp prepare_test_server(context, response) do
      response
      |> TestServer.make_response()
      |> TestServer.with_response(context, "/fees.all")
    end
  end

  describe "/transaction.create validation" do
    @tag fixtures: [:alice, :more_utxos]
    test "incorrect payment in payment list", %{alice: alice} do
      alice_addr = Encoding.to_hex(alice.addr)

      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "payments.amount",
                   "validator" => ":integer"
                 }
               }
             } ==
               WatcherHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => alice_addr,
                   "payments" => [%{"amount" => "zonk", "currency" => @other_token_hex, "owner" => alice_addr}],
                   "fee" => %{"currency" => @eth_hex}
                 }
               )
    end

    @tag fixtures: [:alice, :more_utxos]
    test "too many payments attempted", %{alice: alice} do
      alice_addr = Encoding.to_hex(alice.addr)
      too_many_payments = List.duplicate(%{"amount" => 1, "currency" => @other_token_hex, "owner" => alice_addr}, 5)

      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{
                 "validation_error" => %{"parameter" => "payments", "validator" => "{:too_many_payments, 4}"}
               }
             } ==
               WatcherHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => alice_addr,
                   "payments" => too_many_payments,
                   "fee" => %{"currency" => @eth_hex}
                 }
               )
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "owner should be hex-encoded address" do
      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "owner",
                   "validator" => ":hex"
                 }
               }
             } ==
               WatcherHelper.no_success?(
                 "transaction.create",
                 %{"owner" => "not-a-hex"}
               )
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "metadata should be hex-encoded hash", %{alice: alice} do
      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "metadata",
                   "validator" => ":hex"
                 }
               }
             } ==
               WatcherHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [],
                   "fee" => %{"currency" => @eth_hex},
                   "metadata" => "no-a-hex"
                 }
               )
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "payment should have valid fields", %{alice: alice} do
      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "payments",
                   "validator" => ":list"
                 }
               }
             } ==
               WatcherHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => "not-a-list",
                   "fee" => %{"currency" => @eth_hex}
                 }
               )
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "fee should have valid fields", %{alice: alice} do
      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "fee.currency",
                   "validator" => ":hex"
                 }
               }
             } ==
               WatcherHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [],
                   "fee" => %{"currency" => "123"}
                 }
               )
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "request's fee object is mandatory", %{alice: alice} do
      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "fee",
                   "validator" => ":map"
                 }
               }
             } ==
               WatcherHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => []
                 }
               )
    end
  end

  defp get_block(blknum), do: DB.Repo.get(DB.Block, blknum)

  defp from_hex!(hex) do
    {:ok, result} = Encoding.from_hex(hex)
    result
  end

  defp to_hex_or_nil(hash) do
    case hash do
      nil -> nil
      hash -> Encoding.to_hex(hash)
    end
  end
end
