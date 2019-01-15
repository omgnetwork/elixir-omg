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
  @zero_address_hex Crypto.zero_address() |> OMG.API.Web.Encoding.to_hex()

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
      bob_addr = bob.addr |> OMG.API.Web.Encoding.to_hex()
      alice_addr = alice.addr |> OMG.API.Web.Encoding.to_hex()
      txhash = txhash |> OMG.API.Web.Encoding.to_hex()
      block_hash = block_hash |> OMG.API.Web.Encoding.to_hex()

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
               "txbytes" => "0x" <> txbytes,
               "txindex" => ^txindex
             } = TestHelper.success?("/transaction.get", %{"id" => txhash})

      assert {:ok, _} = Base.decode16(txbytes, case: :lower)
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

      txhash = txhash |> OMG.API.Web.Encoding.to_hex()

      assert %{
               "inputs" => [%{"amount" => 10}, %{"amount" => 20}, %{"amount" => 30}, %{"amount" => 40}],
               "outputs" => [%{"amount" => 1}, %{"amount" => 2}, %{"amount" => 3}, %{"amount" => 4}],
               "txhash" => ^txhash,
               "txindex" => 1
             } = TestHelper.success?("/transaction.get", %{"id" => txhash})
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns error for non exsiting transaction" do
      txhash = <<0::256>> |> OMG.API.Web.Encoding.to_hex()

      assert %{
               "object" => "error",
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
      txhash = txhash |> OMG.API.Web.Encoding.to_hex()
      block_hash = block_hash |> OMG.API.Web.Encoding.to_hex()

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

      address = bob.addr |> OMG.API.Web.Encoding.to_hex()

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

      address = alice.addr |> OMG.API.Web.Encoding.to_hex()

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

      alice_addr = alice.addr |> OMG.API.Web.Encoding.to_hex()
      carol_addr = carol.addr |> OMG.API.Web.Encoding.to_hex()

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

      address = alice.addr |> OMG.API.Web.Encoding.to_hex()

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

      address = alice.addr |> OMG.API.Web.Encoding.to_hex()

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

      address = alice.addr |> OMG.API.Web.Encoding.to_hex()

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

      address = alice.addr |> OMG.API.Web.Encoding.to_hex()

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("/transaction.all", %{"address" => address})
    end

    @tag fixtures: [:alice, :blocks_inserter]
    test "digests transactions correctly", %{
      blocks_inserter: blocks_inserter,
      alice: alice
    } do
      not_eth = <<1::160>>
      not_eth_enc = not_eth |> OMG.API.Web.Encoding.to_hex()

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
             ] = TestHelper.success?("/transaction.all")
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

      address = alice.addr |> OMG.API.Web.Encoding.to_hex()

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

      assert [_, _, _] = TestHelper.success?("/transaction.all")
    end
  end

  describe "getting in-flight exits" do
    @tag fixtures: [:initial_blocks, :bob, :alice]
    test "returns properly formatted in-flight exit data", %{initial_blocks: initial_blocks, bob: bob, alice: alice} do
      test_in_flight_exit_data = fn inputs ->
        positions = Enum.map(inputs, fn {blknum, txindex, _, _} -> {blknum, txindex} end)

        expected_input_txs = get_input_txs(initial_blocks, positions)

        inflight_txbytes =
          inputs
          |> API.TestHelper.create_encoded(@eth, [{bob, 100}])
          |> Base.encode16(case: :upper)

        proofs_size = 1024 * length(inputs)
        sigs_size = 130 * 4

        %{
          # checking just lengths in majority as we prepare verify correctness in the contract in integration tests
          "in_flight_tx" => _in_flight_tx,
          "input_txs" => input_txs,
          # encoded proofs, 1024 bytes each
          "input_txs_inclusion_proofs" => <<_proof::bytes-size(proofs_size)>>,
          # encoded signatures, 130 bytes each
          "in_flight_tx_sigs" => <<_bytes::bytes-size(sigs_size)>>
        } = TestHelper.success?("/inflight_exit.get_data", %{"txbytes" => inflight_txbytes})

        input_txs =
          input_txs
          |> Base.decode16!(case: :upper)
          |> ExRLP.decode()
          |> Enum.map(fn
            "" ->
              nil

            rlp_encoded ->
              {:ok, tx} = Transaction.from_rlp(rlp_encoded)
              tx
          end)

        assert input_txs == expected_input_txs
      end

      test_in_flight_exit_data.([{3000, 1, 0, alice}])
      test_in_flight_exit_data.([{3000, 1, 0, alice}, {2000, 0, 1, alice}])
    end

    # gets the input transactions, as expected from the endpoint - based on the position and initial_blocks fixture
    defp get_input_txs(initial_blocks, positions) do
      filler = List.duplicate(nil, 4 - length(positions))

      initial_blocks
      |> Enum.filter(fn {blknum, txindex, _, _} -> {blknum, txindex} in positions end)
      # reversing, because the inputs are reversed in the IFtx below, and we need that order, not by position!
      |> Enum.reverse()
      |> Enum.map(fn {_, _, _, %Transaction.Recovered{signed_tx: %Transaction.Signed{raw_tx: raw_tx}}} -> raw_tx end)
      |> Enum.concat(filler)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :bob]
    test "behaves well if input is not found", %{bob: bob} do
      inflight_txbytes =
        [{3000, 1, 0, bob}]
        |> API.TestHelper.create_encoded(@eth, [{bob, 150}])
        |> Base.encode16(case: :upper)

      assert %{
               "code" => "in_flight_exit:tx_for_input_not_found",
               "description" => "No transaction that created input."
             } = TestHelper.no_success?("/inflight_exit.get_data", %{"txbytes" => inflight_txbytes})
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "responds with error for malformed in-flight transaction bytes" do
      assert %{
               "code" => "get_in_flight_exit:unknown_error",
               "description" => nil
             } = TestHelper.no_success?("/inflight_exit.get_data", %{"txbytes" => "tx"})
    end
  end
end
