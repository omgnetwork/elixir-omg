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

defmodule OMG.Watcher.Web.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures

  alias OMG.API
  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.Watcher.DB
  alias OMG.Watcher.TestHelper

  @eth Crypto.zero_address()
  @zero_address_hex String.duplicate("00", 20)

  describe "getting transaction by id" do
    @tag fixtures: [:blocks_inserter, :initial_deposits, :alice, :bob]
    test "returns transaction in expected format", %{
      blocks_inserter: blocks_inserter,
      alice: alice,
      bob: bob
    } do
      [{blknum, txindex, txhash, _recovered_tx}] =
        blocks_inserter.([
          {1000,
           [
             OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}])
           ]}
        ])

      %DB.Block{timestamp: timestamp, eth_height: eth_height, hash: block_hash} = DB.Block.get(blknum)
      bob_addr = bob.addr |> TestHelper.to_response_address()
      alice_addr = alice.addr |> TestHelper.to_response_address()
      txhash = Base.encode16(txhash)
      block_hash = Base.encode16(block_hash)

      assert %{
               "block" => %{
                 "blknum" => ^blknum,
                 "eth_height" => ^eth_height,
                 "hash" => ^block_hash,
                 "timestamp" => ^timestamp
               },
               "inputs" => [
                 %{
                   "amount" => 333,
                   "blknum" => 1,
                   "currency" => @zero_address_hex,
                   "oindex" => 0,
                   "owner" => ^alice_addr,
                   "txindex" => 0
                 }
               ],
               "outputs" => [
                 %{
                   "amount" => 300,
                   "blknum" => 1000,
                   "currency" => @zero_address_hex,
                   "oindex" => 0,
                   "owner" => ^bob_addr,
                   "txindex" => 0
                 }
               ],
               "txhash" => ^txhash,
               "txbytes" => txbytes,
               "txindex" => ^txindex
             } = TestHelper.success?("/transaction.get", %{"id" => txhash})

      assert {:ok, _} = Base.decode16(txbytes, case: :mixed)
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
             OMG.API.TestHelper.create_recovered(
               [{1, 0, 0, alice}],
               @eth,
               [{alice, 10}, {alice, 20}, {alice, 30}, {alice, 40}]
             ),
             OMG.API.TestHelper.create_recovered(
               [{1000, 0, 0, alice}, {1000, 0, 1, alice}, {1000, 0, 2, alice}, {1000, 0, 3, alice}],
               @eth,
               [{alice, 1}, {alice, 2}, {alice, 3}, {alice, 4}]
             )
           ]}
        ])

      txhash = Base.encode16(txhash)

      assert %{
               "inputs" => [%{"amount" => 10}, %{"amount" => 20}, %{"amount" => 30}, %{"amount" => 40}],
               "outputs" => [%{"amount" => 1}, %{"amount" => 2}, %{"amount" => 3}, %{"amount" => 4}],
               "txhash" => ^txhash,
               "txindex" => 1
             } = TestHelper.success?("/transaction.get", %{"id" => txhash})
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns error for non exsiting transaction" do
      txhash = "055673FF58D85BFBF6844BAD62361967C7D19B6A4768CE4B54C687B65728D721"

      assert %{
               "code" => "transaction:not_found",
               "description" => "Transaction doesn't exist for provided search criteria"
             } == TestHelper.no_success?("/transaction.get", %{"id" => txhash})
    end
  end

  describe "getting multiple transactions" do
    @tag fixtures: [:initial_blocks]
    test "returns multiple transactions in expected format", %{initial_blocks: initial_blocks} do
      {blknum, txindex, txhash, _recovered_tx} = initial_blocks |> Enum.reverse() |> hd()

      %DB.Block{timestamp: timestamp, eth_height: eth_height, hash: block_hash} = DB.Block.get(blknum)
      txhash = Base.encode16(txhash)
      block_hash = Base.encode16(block_hash)

      assert [
               %{
                 "block" => %{
                   "blknum" => ^blknum,
                   "eth_height" => ^eth_height,
                   "hash" => ^block_hash,
                   "timestamp" => ^timestamp
                 },
                 "results" => [
                   %{
                     "currency" => @zero_address_hex,
                     "value" => value
                   }
                 ],
                 "txhash" => ^txhash,
                 "txindex" => ^txindex
               }
               | _
             ] = TestHelper.success?("/transaction.all")

      assert is_integer(value)
    end

    @tag fixtures: [:blocks_inserter, :alice]
    test "returns tx from a particular block", %{
      blocks_inserter: blocks_inserter,
      alice: alice
    } do
      blocks_inserter.([
        {1000, [OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 300}])]},
        {2000,
         [
           OMG.API.TestHelper.create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 300}]),
           OMG.API.TestHelper.create_recovered([{2000, 1, 0, alice}], @eth, [{alice, 300}])
         ]}
      ])

      assert [%{"block" => %{"blknum" => 2000}, "txindex" => 1}, %{"block" => %{"blknum" => 2000}, "txindex" => 0}] =
               TestHelper.success?("/transaction.all", %{"blknum" => 2000})

      assert [] = TestHelper.success?("/transaction.all", %{"blknum" => 3000})
    end

    @tag fixtures: [:blocks_inserter, :alice, :bob]
    test "returns tx from a particular block that contains requested address as the sender", %{
      blocks_inserter: blocks_inserter,
      alice: alice,
      bob: bob
    } do
      blocks_inserter.([
        {1000, [OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 300}])]},
        {2000,
         [
           OMG.API.TestHelper.create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 300}]),
           OMG.API.TestHelper.create_recovered([{2, 0, 0, bob}], @eth, [{bob, 300}])
         ]}
      ])

      {:ok, address} = Crypto.encode_address(bob.addr)

      assert [%{"block" => %{"blknum" => 2000}, "txindex" => 1}] =
               TestHelper.success?("/transaction.all", %{"address" => address, "blknum" => 2000})
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
           OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}])
         ]}
      ])

      {:ok, address} = Crypto.encode_address(alice.addr)

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("/transaction.all", %{"address" => address})
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
           OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}]),
           OMG.API.TestHelper.create_recovered([{2, 0, 0, bob}], @eth, [{bob, 300}]),
           OMG.API.TestHelper.create_recovered([{1000, 1, 0, bob}], @eth, [{alice, 300}])
         ]}
      ])

      {:ok, alice_addr} = Crypto.encode_address(alice.addr)
      {:ok, carol_addr} = Crypto.encode_address(carol.addr)

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 2}, %{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("/transaction.all", %{"address" => alice_addr})

      assert [] = TestHelper.success?("/transaction.all", %{"address" => carol_addr})
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
           OMG.API.TestHelper.create_recovered([{2, 0, 0, bob}], @eth, [{alice, 100}])
         ]}
      ])

      {:ok, address} = Crypto.encode_address(alice.addr)

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("/transaction.all", %{"address" => address})
    end

    @tag fixtures: [:blocks_inserter, :alice]
    test "returns tx that contains requested address as both sender & recipient is listed once", %{
      blocks_inserter: blocks_inserter,
      alice: alice
    } do
      blocks_inserter.([
        {1000,
         [
           OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 100}])
         ]}
      ])

      {:ok, address} = Crypto.encode_address(alice.addr)

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("/transaction.all", %{"address" => address})
    end

    @tag fixtures: [:blocks_inserter, :alice]
    test "returns tx without inputs and contains requested address as recipient", %{
      blocks_inserter: blocks_inserter,
      alice: alice
    } do
      blocks_inserter.([
        {1000,
         [
           OMG.API.TestHelper.create_recovered([], @eth, [{alice, 10}])
         ]}
      ])

      {:ok, address} = Crypto.encode_address(alice.addr)

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("/transaction.all", %{"address" => address})
    end

    @tag fixtures: [:blocks_inserter, :initial_deposits, :alice, :bob]
    test "returns tx without outputs (amount = 0) and contains requested address as sender", %{
      blocks_inserter: blocks_inserter,
      alice: alice,
      bob: bob
    } do
      blocks_inserter.([
        {1000,
         [
           OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 0}])
         ]}
      ])

      {:ok, address} = Crypto.encode_address(alice.addr)

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("/transaction.all", %{"address" => address})
    end

    @tag fixtures: [:alice, :blocks_inserter]
    test "digests transactions correctly", %{
      blocks_inserter: blocks_inserter,
      alice: alice
    } do
      not_eth = <<1::160>>
      # after we serve addresses in consistent "0x...." format, this can be undone
      "0x" <> not_eth_enc = Crypto.encode_address!(not_eth)

      blocks_inserter.([
        {1000,
         [
           OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], [
             {alice, @eth, 3},
             {alice, not_eth, 4},
             {alice, not_eth, 5}
           ])
         ]}
      ])

      assert [
               %{
                 "results" => [
                   %{"currency" => @zero_address_hex, "value" => 3},
                   %{"currency" => ^not_eth_enc, "value" => 9}
                 ]
               }
             ] = TestHelper.success?("/transaction.all", %{})
    end
  end

  describe "getting transactions with limit on number of transactions" do
    @tag fixtures: [:alice, :bob, :initial_deposits, :blocks_inserter]
    test "returns only limited list of transactions", %{
      blocks_inserter: blocks_inserter,
      alice: alice,
      bob: bob
    } do
      blocks_inserter.([
        {1000,
         [
           OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 3}]),
           OMG.API.TestHelper.create_recovered([{1_000, 0, 0, bob}], @eth, [{bob, 2}])
         ]},
        {2000,
         [
           OMG.API.TestHelper.create_recovered([{1_000, 1, 0, bob}], @eth, [{alice, 1}])
         ]}
      ])

      {:ok, address} = Crypto.encode_address(alice.addr)

      assert [%{"block" => %{"blknum" => 2000}, "txindex" => 0}, %{"block" => %{"blknum" => 1000}, "txindex" => 1}] =
               TestHelper.success?("/transaction.all", %{limit: 2})

      assert [%{"block" => %{"blknum" => 2000}, "txindex" => 0}, %{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("/transaction.all", %{address: address, limit: 2})
    end

    @tag fixtures: [:alice, :bob, :blocks_inserter]
    test "limiting all transactions without address filter", %{
      blocks_inserter: blocks_inserter,
      alice: alice,
      bob: bob
    } do
      blocks_inserter.([
        {1000,
         [
           OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 3}]),
           OMG.API.TestHelper.create_recovered([{1_000, 0, 0, bob}], @eth, [{alice, 2}])
         ]},
        {2000,
         [
           OMG.API.TestHelper.create_recovered([{1_000, 1, 0, alice}], @eth, [{bob, 1}])
         ]}
      ])

      assert [_, _, _] = TestHelper.success?("/transaction.all", %{})
    end
  end

  describe "getting in-flight exits" do
    @tag fixtures: [:initial_blocks, :bob]
    test "prepares the IFE info - 1 input", %{initial_blocks: initial_blocks, bob: bob} do
      encoded_inputs = get_compare_in_txs(initial_blocks, [{3000, 1}])

      # see initial_blocks, we're combining two outputs from those transactions
      tx = API.TestHelper.create_encoded([{3000, 1, 0, bob}], @eth, [{bob, 150}])

      assert %{
               # checking just lengths in majority as we prepare verify correctness in the contract in integration tests
               # the byte size is hard-coded - how much does it bother us?
               "in_flight_tx" => _,
               "input_txs" => ^encoded_inputs,
               # a non-encoded proof, 512 bytes each
               "input_txs_inclusion_proofs" => _,
               # two non-encoded signatures, 65 bytes each, second one is zero-bytes, that's ok with contract
               "in_flight_tx_sigs" => _
             } = TestHelper.success?("/transaction.get_in_flight_exit_data", %{"transaction" => tx})
    end

    @tag fixtures: [:initial_blocks, :alice, :bob]
    test "prepares the IFE info - 2 inputs", %{initial_blocks: initial_blocks, alice: alice, bob: bob} do
      encoded_inputs = get_compare_in_txs(initial_blocks, [{3000, 1}, {2000, 0}])

      # see initial_blocks, we're combining two outputs from those transactions
      tx = API.TestHelper.create_encoded([{3000, 1, 0, bob}, {2000, 0, 1, alice}], @eth, [{bob, 151}])

      assert %{
               # see 1 input case for comments
               "in_flight_tx" => _,
               "input_txs" => ^encoded_inputs,
               "input_txs_inclusion_proofs" => _,
               "in_flight_tx_sigs" => _
             } = TestHelper.success?("/transaction.get_in_flight_exit_data", %{"transaction" => tx})
    end

    # gets the input transactions, as expected from the endpoint - based on the position and initial_blocks fixture
    defp get_compare_in_txs(initial_blocks, positions) do
      filler = List.duplicate(<<>>, 4 - length(positions))

      initial_blocks
      |> Enum.filter(fn {blknum, txindex, _, _} -> {blknum, txindex} in positions end)
      # reversing, because the inputs are reversed in the IFtx below, and we need that order, not by position!
      |> Enum.reverse()
      |> Enum.map(fn {_, _, _, %Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: raw_tx}}} ->
        Transaction.encode(raw_tx)
      end)
      |> Enum.concat(filler)
      |> ExRLP.encode()
      |> Base.encode16(case: :upper)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :bob]
    test "behaves well if inputs not found", %{bob: bob} do
      tx = API.TestHelper.create_encoded([{3000, 1, 0, bob}], @eth, [{bob, 150}])

      assert %{
               "code" => "in_flight_exit:tx_for_input_not_found",
               "description" => "No transaction that created input."
             } = TestHelper.no_success?("/transaction.get_in_flight_exit_data", %{"transaction" => tx})
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "behaves well if IFtx malformed; behavior from OMG.API.Core.recover_tx/1" do
      assert %{
               "code" => "get_in_flight_exit:malformed_transaction_rlp",
               "description" => nil
             } = TestHelper.no_success?("/transaction.get_in_flight_exit_data", %{"transaction" => "tx"})
    end
  end
end
