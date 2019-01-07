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
    @tag fixtures: [:initial_blocks, :alice, :bob]
    test "returns transaction in expected format", %{
      initial_blocks: initial_blocks,
      alice: alice,
      bob: bob
    } do
      {blknum, txindex, txhash, _recovered_tx} = initial_blocks |> hd()

      %DB.Block{timestamp: timestamp, eth_height: eth_height} = DB.Block.get(blknum)
      bob_addr = bob.addr |> TestHelper.to_response_address()
      alice_addr = alice.addr |> TestHelper.to_response_address()
      txhash = Base.encode16(txhash)
      zero_addr = String.duplicate("0", 2 * 20)
      zero_sign = String.duplicate("0", 2 * 65)

      assert %{
               "txid" => ^txhash,
               "txblknum" => ^blknum,
               "txindex" => ^txindex,
               "blknum1" => 1,
               "txindex1" => 0,
               "oindex1" => 0,
               "blknum2" => 0,
               "txindex2" => 0,
               "oindex2" => 0,
               "cur12" => ^zero_addr,
               "newowner1" => ^bob_addr,
               "amount1" => 300,
               "newowner2" => ^zero_addr,
               "amount2" => 0,
               "sig1" => <<_sig1::binary-size(130)>>,
               "sig2" => ^zero_sign,
               "spender1" => ^alice_addr,
               "spender2" => nil,
               "eth_height" => ^eth_height,
               "timestamp" => ^timestamp
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

  describe "getting transactions by address" do
    @tag fixtures: [:alice, :bob, :phoenix_ecto_sandbox]
    test "returns tx that contains requested address as the sender and not recipient", %{
      alice: alice,
      bob: bob
    } do
      OMG.Watcher.DB.EthEvent.insert_deposits([
        %{owner: alice.addr, currency: @eth, amount: 1, blknum: 1}
      ])

      txs = [
        OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}]),
        OMG.API.TestHelper.create_recovered([{1, 1, 0, bob}], @eth, [{bob, 300}])
      ]

      alice_address = alice.addr |> TestHelper.to_response_address()
      bob_address = bob.addr |> TestHelper.to_response_address()

      expected_result = [
        %{
          "spender1" => alice_address,
          "spender2" => nil,
          "newowner1" => bob_address,
          "newowner2" => @zero_address_hex,
          "eth_height" => 1
        }
      ]

      assert_transactions_filter_by_address_endpoint(txs, expected_result, alice)
    end

    @tag fixtures: [:alice, :bob, :phoenix_ecto_sandbox]
    test "returns tx that contains requested address as both sender & recipient is listed once", %{
      alice: alice,
      bob: bob
    } do
      txs = [
        OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{alice, 300}]),
        OMG.API.TestHelper.create_recovered([{1, 1, 0, bob}], @eth, [{bob, 300}])
      ]

      alice_address = alice.addr |> TestHelper.to_response_address()

      expected_result = [
        %{
          "spender1" => alice_address,
          "spender2" => nil,
          "newowner1" => alice_address,
          "newowner2" => @zero_address_hex,
          "eth_height" => 1
        }
      ]

      assert_transactions_filter_by_address_endpoint(txs, expected_result, alice)
    end

    @tag fixtures: [:alice, :bob, :phoenix_ecto_sandbox]
    test "returns tx without inputs and contains requested address as recipient", %{
      alice: alice,
      bob: bob
    } do
      txs = [
        OMG.API.TestHelper.create_recovered([], @eth, [{alice, 300}]),
        OMG.API.TestHelper.create_recovered([{1, 1, 0, bob}], @eth, [{bob, 300}])
      ]

      alice_address = alice.addr |> TestHelper.to_response_address()

      expected_result = [
        %{
          "spender1" => nil,
          "spender2" => nil,
          "newowner1" => alice_address,
          "newowner2" => @zero_address_hex,
          "eth_height" => 1
        }
      ]

      assert_transactions_filter_by_address_endpoint(txs, expected_result, alice)
    end

    @tag fixtures: [:alice, :bob, :phoenix_ecto_sandbox]
    test "returns tx without outputs (amount = 0) and contains requested address as sender", %{
      alice: alice,
      bob: bob
    } do
      OMG.Watcher.DB.EthEvent.insert_deposits([
        %{owner: alice.addr, currency: @eth, amount: 1, blknum: 1}
      ])

      txs = [
        OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 0}]),
        OMG.API.TestHelper.create_recovered([{1, 1, 0, bob}], @eth, [{bob, 300}])
      ]

      alice_address = alice.addr |> TestHelper.to_response_address()
      bob_address = bob.addr |> TestHelper.to_response_address()

      expected_result = [
        %{
          "spender1" => alice_address,
          "spender2" => nil,
          "newowner1" => bob_address,
          "newowner2" => @zero_address_hex,
          "eth_height" => 1
        }
      ]

      assert_transactions_filter_by_address_endpoint(txs, expected_result, alice)
    end

    @tag fixtures: [:alice, :bob, :phoenix_ecto_sandbox]
    test "returns last 2 transactions", %{
      alice: alice,
      bob: bob
    } do
      OMG.Watcher.DB.EthEvent.insert_deposits([
        %{owner: alice.addr, currency: @eth, amount: 3, blknum: 1}
      ])

      txs = [
        OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 3}]),
        OMG.API.TestHelper.create_recovered([{1_000, 0, 0, bob}], @eth, [{alice, 2}]),
        OMG.API.TestHelper.create_recovered([{1_000, 1, 0, alice}], @eth, [{bob, 1}])
      ]

      alice_address = alice.addr |> TestHelper.to_response_address()
      bob_address = bob.addr |> TestHelper.to_response_address()

      expected_result = [
        %{
          "spender1" => alice_address,
          "spender2" => nil,
          "newowner1" => bob_address,
          "newowner2" => @zero_address_hex,
          "eth_height" => 1
        },
        %{
          "spender1" => bob_address,
          "spender2" => nil,
          "newowner1" => alice_address,
          "newowner2" => @zero_address_hex,
          "eth_height" => 1
        }
      ]

      assert_transactions_filter_by_address_endpoint(txs, expected_result, bob, 2)
    end

    defp assert_transactions_filter_by_address_endpoint(
           txs,
           expected_result,
           entity,
           limit \\ 200
         ) do
      {:ok, _} =
        DB.Transaction.update_with(%{
          transactions: txs,
          blknum: 1_000,
          eth_height: 1,
          blkhash: <<?#::256>>,
          timestamp: :os.system_time(:second)
        })

      {:ok, address} = Crypto.encode_address(entity.addr)

      txs = TestHelper.success?("/transaction.all", %{"address" => address, "limit" => limit})

      assert expected_result ==
               txs
               |> Enum.map(&Map.take(&1, ["spender1", "spender2", "newowner1", "newowner2", "eth_height"]))
    end
  end

  describe "getting transactions with limit on number of transactions" do
    @tag fixtures: [:initial_blocks]
    test "limiting all transactions without address filter" do
      txs = TestHelper.success?("/transaction.all", %{"limit" => 2})

      assert [
               %{
                 "txblknum" => 3000,
                 "txindex" => 1,
                 "eth_height" => 1,
                 "timestamp" => 1_540_465_606
               },
               %{
                 "txblknum" => 3000,
                 "txindex" => 0,
                 "eth_height" => 1,
                 "timestamp" => 1_540_465_606
               }
             ] ==
               txs
               |> Enum.map(&Map.take(&1, ["txblknum", "txindex", "eth_height", "timestamp"]))
    end
  end

  describe "getting in-flight exits" do
    @tag fixtures: [:initial_blocks, :bob, :alice]
    test "returns properly formatted in-flight exit data", %{initial_blocks: initial_blocks, bob: bob, alice: alice} do
      test_in_flight_exit_data = fn inputs ->
        positions =
          inputs
          |> Enum.map(fn {blknum, txindex, _, _} -> {blknum, txindex} end)

        expected_input_txs = get_input_txs(initial_blocks, positions)

        # see initial_blocks, we're combining two outputs from those transactions
        tx = API.TestHelper.create_encoded(inputs, @eth, [{bob, 100}])

        proofs_size = 1024 * length(inputs)
        sigs_size = 65 * 4

        %{
          # checking just lengths in majority as we prepare verify correctness in the contract in integration tests
          # the byte size is hard-coded - how much does it bother us?
          "in_flight_tx" => _in_flight_tx,
          "input_txs" => input_txs,
          # a non-encoded proof, 512 bytes each
          "input_txs_inclusion_proofs" => <<_proof::bytes-size(proofs_size)>>,
          # two non-encoded signatures, 65 bytes each, second one is zero-bytes, that's ok with contract
          "in_flight_tx_sigs" => <<_bytes::bytes-size(sigs_size)>>
        } = TestHelper.success?("/transaction.get_in_flight_exit_data", %{"transaction" => tx})

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
