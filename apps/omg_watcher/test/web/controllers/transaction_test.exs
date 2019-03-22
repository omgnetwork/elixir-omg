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
  use OMG.Fixtures

  alias OMG.RPC.Web.Encoding
  alias OMG.TestHelper, as: Test
  alias OMG.Watcher.DB
  alias OMG.Watcher.TestHelper

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @other_token <<127::160>>
  @eth_hex OMG.Eth.zero_address() |> Encoding.to_hex()
  @other_token_hex @other_token |> Encoding.to_hex()

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
             Test.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 300}])
           ]}
        ])

      %DB.Block{timestamp: timestamp, eth_height: eth_height, hash: block_hash} = DB.Block.get(blknum)
      bob_addr = bob.addr |> Encoding.to_hex()
      alice_addr = alice.addr |> Encoding.to_hex()
      txhash = txhash |> Encoding.to_hex()
      block_hash = block_hash |> Encoding.to_hex()

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
                   "currency" => @eth_hex,
                   "oindex" => 0,
                   "owner" => ^alice_addr,
                   "txindex" => 0,
                   "utxo_pos" => 1_000_000_000
                 }
               ],
               "outputs" => [
                 %{
                   "amount" => 300,
                   "blknum" => 1000,
                   "currency" => @eth_hex,
                   "oindex" => 0,
                   "owner" => ^bob_addr,
                   "txindex" => 0,
                   "utxo_pos" => 1_000_000_000_000
                 }
               ],
               "txhash" => ^txhash,
               "txbytes" => "0x" <> txbytes,
               "txindex" => ^txindex
             } = TestHelper.success?("transaction.get", %{"id" => txhash})

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

      txhash = txhash |> Encoding.to_hex()

      assert %{
               "inputs" => [%{"amount" => 10}, %{"amount" => 20}, %{"amount" => 30}, %{"amount" => 40}],
               "outputs" => [%{"amount" => 1}, %{"amount" => 2}, %{"amount" => 3}, %{"amount" => 4}],
               "txhash" => ^txhash,
               "txindex" => 1
             } = TestHelper.success?("transaction.get", %{"id" => txhash})
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns error for non exsiting transaction" do
      txhash = <<0::256>> |> Encoding.to_hex()

      assert %{
               "object" => "error",
               "code" => "transaction:not_found",
               "description" => "Transaction doesn't exist for provided search criteria"
             } == TestHelper.no_success?("transaction.get", %{"id" => txhash})
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
             } == TestHelper.no_success?("transaction.get", %{"id" => "0x50e901b98fe3389e32d56166a13a88208b03ea75"})
    end
  end

  describe "getting multiple transactions" do
    @tag fixtures: [:initial_blocks]
    test "returns multiple transactions in expected format", %{initial_blocks: initial_blocks} do
      {blknum, txindex, txhash, _recovered_tx} = initial_blocks |> Enum.reverse() |> hd()

      %DB.Block{timestamp: timestamp, eth_height: eth_height, hash: block_hash} = DB.Block.get(blknum)
      txhash = txhash |> Encoding.to_hex()
      block_hash = block_hash |> Encoding.to_hex()

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
                     "currency" => @eth_hex,
                     "value" => value
                   }
                 ],
                 "txhash" => ^txhash,
                 "txindex" => ^txindex
               }
               | _
             ] = TestHelper.success?("transaction.all")

      assert is_integer(value)
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
               TestHelper.success?("transaction.all", %{"blknum" => 2000})

      assert [] = TestHelper.success?("transaction.all", %{"blknum" => 3000})
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

      address = bob.addr |> Encoding.to_hex()

      assert [%{"block" => %{"blknum" => 2000}, "txindex" => 1}] =
               TestHelper.success?("transaction.all", %{"address" => address, "blknum" => 2000})
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

      address = alice.addr |> Encoding.to_hex()

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("transaction.all", %{"address" => address})
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

      alice_addr = alice.addr |> Encoding.to_hex()
      carol_addr = carol.addr |> Encoding.to_hex()

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 2}, %{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("transaction.all", %{"address" => alice_addr})

      assert [] = TestHelper.success?("transaction.all", %{"address" => carol_addr})
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

      address = alice.addr |> Encoding.to_hex()

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("transaction.all", %{"address" => address})
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

      address = alice.addr |> Encoding.to_hex()

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("transaction.all", %{"address" => address})
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

      address = alice.addr |> Encoding.to_hex()

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("transaction.all", %{"address" => address})
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
           Test.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 0}])
         ]}
      ])

      address = alice.addr |> Encoding.to_hex()

      assert [%{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("transaction.all", %{"address" => address})
    end

    @tag fixtures: [:alice, :blocks_inserter]
    test "digests transactions correctly", %{
      blocks_inserter: blocks_inserter,
      alice: alice
    } do
      not_eth = <<1::160>>
      not_eth_enc = not_eth |> Encoding.to_hex()

      blocks_inserter.([
        {1000,
         [
           Test.create_recovered([{1, 0, 0, alice}], [
             {alice, @eth, 3},
             {alice, not_eth, 4},
             {alice, not_eth, 5}
           ])
         ]}
      ])

      assert [
               %{
                 "results" => [
                   %{"currency" => @eth_hex, "value" => 3},
                   %{"currency" => ^not_eth_enc, "value" => 9}
                 ]
               }
             ] = TestHelper.success?("transaction.all")
    end

    @tag fixtures: [:initial_blocks]
    test "returns transactions containing metadata", %{initial_blocks: initial_blocks} do
      {blknum, txindex, txhash, recovered_tx} = initial_blocks |> Enum.find(&match?({2000, 0, _, _}, &1))

      expected_metadata = recovered_tx.signed_tx.raw_tx.metadata |> Encoding.to_hex()
      expected_txhash = Encoding.to_hex(txhash)

      assert [
               %{
                 "block" => %{"blknum" => ^blknum},
                 "metadata" => ^expected_metadata,
                 "txhash" => ^expected_txhash,
                 "txindex" => ^txindex
               }
             ] = TestHelper.success?("transaction.all", %{"metadata" => expected_metadata})
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
           Test.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 3}]),
           Test.create_recovered([{1_000, 0, 0, bob}], @eth, [{bob, 2}])
         ]},
        {2000,
         [
           Test.create_recovered([{1_000, 1, 0, bob}], @eth, [{alice, 1}])
         ]}
      ])

      address = alice.addr |> Encoding.to_hex()

      assert [%{"block" => %{"blknum" => 2000}, "txindex" => 0}, %{"block" => %{"blknum" => 1000}, "txindex" => 1}] =
               TestHelper.success?("transaction.all", %{limit: 2})

      assert [%{"block" => %{"blknum" => 2000}, "txindex" => 0}, %{"block" => %{"blknum" => 1000}, "txindex" => 0}] =
               TestHelper.success?("transaction.all", %{address: address, limit: 2})
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
           Test.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 3}]),
           Test.create_recovered([{1_000, 0, 0, bob}], @eth, [{alice, 2}])
         ]},
        {2000,
         [
           Test.create_recovered([{1_000, 1, 0, alice}], @eth, [{bob, 1}])
         ]}
      ])

      assert [_, _, _] = TestHelper.success?("transaction.all")
    end
  end

  describe "submitting transaction to child chain" do
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
             } == TestHelper.no_success?("transaction.submit", %{"transaction" => hex_without_0x})
    end
  end

  describe "creating transaction" do
    deffixture more_utxos(alice, blocks_inserter) do
      [
        {5000,
         [
           Test.create_recovered([], @eth, [{alice, 40}, {alice, 42}, {alice, 43}, {alice, 44}]),
           Test.create_recovered([], @eth, [{alice, 41}, {alice, 45}]),
           Test.create_recovered([], @other_token, [{alice, 5}, {alice, 110}, {alice, 15}]),
           Test.create_recovered([], @other_token, [{alice, 105}, {alice, 10}, {alice, 115}])
         ]}
      ]
      |> blocks_inserter.()
    end

    @tag fixtures: [:alice, :bob, :more_utxos]
    test "returns appropriate schema", %{alice: alice, bob: bob} do
      alias OMG.Utxo
      require Utxo

      alice_to_bob = 100
      fee = 5
      metadata = (alice.addr <> bob.addr) |> OMG.Crypto.hash() |> Encoding.to_hex()

      alice_addr = Encoding.to_hex(alice.addr)
      bob_addr = Encoding.to_hex(bob.addr)
      blknum = 5000

      assert %{
               "result" => "complete",
               "transactions" => [
                 %{
                   "inputs" => [
                     %{
                       "owner" => ^alice_addr,
                       "currency" => @eth_hex,
                       "blknum" => ^blknum,
                       "txindex" => txindex,
                       "oindex" => oindex,
                       "utxo_pos" => utxo_pos
                     }
                     | _
                   ],
                   "outputs" => [
                     %{"amount" => ^alice_to_bob, "currency" => @eth_hex, "owner" => ^bob_addr},
                     %{"currency" => @eth_hex, "owner" => ^alice_addr, "amount" => _rest}
                   ],
                   "metadata" => ^metadata,
                   "fee" => %{"amount" => ^fee, "currency" => @eth_hex},
                   "txbytes" => "0x" <> _txbytes
                 }
               ]
             } =
               TestHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => alice_addr,
                   "payments" => [
                     %{"amount" => alice_to_bob, "currency" => @eth_hex, "owner" => bob_addr}
                   ],
                   "fee" => %{"amount" => fee, "currency" => @eth_hex},
                   "metadata" => metadata
                 }
               )

      assert Utxo.position(blknum, txindex, oindex) |> Utxo.Position.encode() == utxo_pos
    end

    @tag fixtures: [:alice, :bob, :more_utxos]
    test "returns correctly formed transaction", %{alice: alice, bob: bob} do
      alias OMG.State.Transaction

      alice_to_bob = 100
      fee = 5
      metadata = (alice.addr <> bob.addr) |> OMG.Crypto.hash()

      alice_addr = Encoding.to_hex(alice.addr)

      assert %{
               "result" => "complete",
               "transactions" => [%{"txbytes" => tx_hex}]
             } =
               TestHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => alice_addr,
                   "payments" => [
                     %{"amount" => alice_to_bob, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)}
                   ],
                   "fee" => %{"amount" => fee, "currency" => @eth_hex},
                   "metadata" => Encoding.to_hex(metadata)
                 }
               )

      assert {:ok, txbytes} = Encoding.from_hex(tx_hex)
      assert {:ok, raw_tx} = Transaction.decode(txbytes)

      alice_addr = alice.addr
      bob_addr = bob.addr

      assert %Transaction{
               inputs: [%{blknum: 5000} | _],
               outputs: [
                 %{owner: ^bob_addr, currency: @eth, amount: ^alice_to_bob},
                 %{owner: ^alice_addr, currency: @eth}
                 | _
               ],
               metadata: ^metadata
             } = raw_tx
    end

    @tag fixtures: [:alice, :bob, :more_utxos, :blocks_inserter]
    test "allows to pay single token tx", %{alice: alice, bob: bob, blocks_inserter: blocks_inserter} do
      alice_balance = balance_in_token(alice.addr, @eth)
      bob_balance = balance_in_token(bob.addr, @eth)

      payment = 100
      fee = 5

      assert %{
               "result" => "complete",
               "transactions" => [%{"txbytes" => tx_hex}]
             } =
               TestHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => payment, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)}
                   ],
                   "fee" => %{"amount" => fee, "currency" => @eth_hex}
                 }
               )

      make_payments(7000, alice, [tx_hex], blocks_inserter)

      assert alice_balance - (payment + fee) == balance_in_token(alice.addr, @eth)
      assert bob_balance + payment == balance_in_token(bob.addr, @eth)
    end

    @tag fixtures: [:alice, :bob, :more_utxos, :blocks_inserter]
    test "advice on merge single token tx", %{alice: alice, bob: bob, blocks_inserter: blocks_inserter} do
      alice_balance = balance_in_token(alice.addr, @eth)
      max_spendable = max_amount_spendable_in_single_tx(alice.addr, @eth)

      payment = max_spendable + 10
      fee = 5

      assert %{
               "result" => "intermediate",
               "transactions" => transactions
             } =
               TestHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => payment, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)}
                   ],
                   "fee" => %{"amount" => fee, "currency" => @eth_hex}
                 }
               )

      make_payments(7000, alice, Enum.map(transactions, & &1["txbytes"]), blocks_inserter)

      assert alice_balance == balance_in_token(alice.addr, @eth)
      assert max_amount_spendable_in_single_tx(alice.addr, @eth) >= payment
    end

    @tag fixtures: [:alice, :bob, :more_utxos]
    test "advice on merge does not merge single utxo", %{alice: alice, bob: bob} do
      max_spendable = max_amount_spendable_in_single_tx(alice.addr, @eth)

      payment = max_spendable + 1

      assert %{
               "result" => "intermediate",
               "transactions" => [transaction]
             } =
               TestHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => payment, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)}
                   ],
                   "fee" => %{"amount" => 0, "currency" => @eth_hex}
                 }
               )

      require OMG.State.Transaction
      assert OMG.State.Transaction.max_inputs() == length(transaction["inputs"])
    end

    @tag fixtures: [:alice, :bob, :more_utxos, :blocks_inserter]
    test "allows to pay multi token tx", %{alice: alice, bob: bob, blocks_inserter: blocks_inserter} do
      alice_eth = balance_in_token(alice.addr, @eth)
      alice_token = balance_in_token(alice.addr, @other_token)
      bob_eth = balance_in_token(bob.addr, @eth)
      bob_token = balance_in_token(bob.addr, @other_token)

      payment_eth = 100
      payment_token = 110
      fee = 5

      assert %{
               "result" => "complete",
               "transactions" => [%{"txbytes" => tx_hex}]
             } =
               TestHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => payment_eth, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)},
                     %{"amount" => payment_token, "currency" => @other_token_hex, "owner" => Encoding.to_hex(bob.addr)}
                   ],
                   "fee" => %{"amount" => fee, "currency" => @eth_hex}
                 }
               )

      make_payments(7000, alice, [tx_hex], blocks_inserter)

      assert alice_eth - (payment_eth + fee) == balance_in_token(alice.addr, @eth)
      assert alice_token - payment_token == balance_in_token(alice.addr, @other_token)
      assert bob_eth + payment_eth == balance_in_token(bob.addr, @eth)
      assert bob_token + payment_token == balance_in_token(bob.addr, @other_token)
    end

    @tag fixtures: [:alice, :bob, :more_utxos, :blocks_inserter]
    test "allows to pay other token tx with fee in different currency",
         %{alice: alice, bob: bob, blocks_inserter: blocks_inserter} do
      alice_eth = balance_in_token(alice.addr, @eth)
      alice_token = balance_in_token(alice.addr, @other_token)
      bob_token = balance_in_token(bob.addr, @other_token)

      payment_token = 110
      fee = 5

      assert %{
               "result" => "complete",
               "transactions" => [%{"txbytes" => tx_hex}]
             } =
               TestHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => payment_token, "currency" => @other_token_hex, "owner" => Encoding.to_hex(bob.addr)}
                   ],
                   "fee" => %{"amount" => fee, "currency" => @eth_hex}
                 }
               )

      make_payments(7000, alice, [tx_hex], blocks_inserter)

      assert alice_eth - fee == balance_in_token(alice.addr, @eth)
      assert alice_token - payment_token == balance_in_token(alice.addr, @other_token)
      assert bob_token + payment_token == balance_in_token(bob.addr, @other_token)
    end

    @tag fixtures: [:alice, :bob, :more_utxos, :blocks_inserter]
    test "advice on merge multi token tx", %{alice: alice, bob: bob, blocks_inserter: blocks_inserter} do
      alice_eth = balance_in_token(alice.addr, @eth)
      alice_token = balance_in_token(alice.addr, @other_token)
      bob_eth = balance_in_token(bob.addr, @eth)
      bob_token = balance_in_token(bob.addr, @other_token)

      payment_eth = max_amount_spendable_in_single_tx(alice.addr, @eth) + 10
      payment_token = max_amount_spendable_in_single_tx(alice.addr, @other_token) + 10
      fee = 5

      assert %{
               "result" => "intermediate",
               "transactions" => transactions
             } =
               TestHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => payment_eth, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)},
                     %{"amount" => payment_token, "currency" => @other_token_hex, "owner" => Encoding.to_hex(bob.addr)}
                   ],
                   "fee" => %{"amount" => fee, "currency" => @eth_hex}
                 }
               )

      make_payments(7000, alice, Enum.map(transactions, & &1["txbytes"]), blocks_inserter)

      assert alice_eth == balance_in_token(alice.addr, @eth)
      assert alice_token == balance_in_token(alice.addr, @other_token)
      assert bob_eth == balance_in_token(bob.addr, @eth)
      assert bob_token == balance_in_token(bob.addr, @other_token)

      assert max_amount_spendable_in_single_tx(alice.addr, @eth) >= payment_eth
      assert max_amount_spendable_in_single_tx(alice.addr, @other_token) >= payment_token
    end

    @tag fixtures: [:alice, :bob, :more_utxos]
    test "insufficient funds returns custom error", %{alice: alice, bob: bob} do
      balance = balance_in_token(alice.addr, @eth)
      payment = balance + 10
      fee = 5

      assert %{
               "object" => "error",
               "code" => "transaction.create:insufficient_funds",
               "description" => "Account balance is too low to satisfy the payment.",
               "messages" => [%{"token" => @eth_hex, "missing" => payment + fee - balance}]
             } ==
               TestHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => payment, "currency" => @eth_hex, "owner" => Encoding.to_hex(bob.addr)}
                   ],
                   "fee" => %{"amount" => fee, "currency" => @eth_hex}
                 }
               )
    end

    @tag fixtures: [:alice, :bob, :more_utxos]
    test "unknown owner returns insufficient funds error", %{alice: alice, bob: bob} do
      assert 0 == balance_in_token(bob.addr, @eth)
      payment = 25
      fee = 5

      assert %{
               "object" => "error",
               "code" => "transaction.create:insufficient_funds",
               "description" => "Account balance is too low to satisfy the payment.",
               "messages" => [%{"token" => @eth_hex, "missing" => payment + fee}]
             } ==
               TestHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(bob.addr),
                   "payments" => [
                     %{"amount" => payment, "currency" => @eth_hex, "owner" => Encoding.to_hex(alice.addr)}
                   ],
                   "fee" => %{"amount" => fee, "currency" => @eth_hex}
                 }
               )
    end

    @tag fixtures: [:alice, :more_utxos, :blocks_inserter]
    test "does not return txbytes when spend owner is not provided", %{alice: alice} do
      payment = 100
      fee = 5
      alice_addr = Encoding.to_hex(alice.addr)

      assert %{
               "result" => "complete",
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
               TestHelper.success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => payment, "currency" => @eth_hex}
                   ],
                   "fee" => %{"amount" => fee, "currency" => @eth_hex}
                 }
               )
    end

    @tag fixtures: [:alice, :bob, :more_utxos]
    test "total number of outputs exceeds allowed outputs returns custom error", %{alice: alice, bob: bob} do
      bob_addr = Encoding.to_hex(bob.addr)

      assert %{
               "object" => "error",
               "code" => "transaction.create:too_many_outputs",
               "description" => "Total number of payments + change + fees exceed maximum allowed outputs."
             } ==
               TestHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [
                     %{"amount" => 1, "currency" => @other_token_hex, "owner" => bob_addr},
                     %{"amount" => 2, "currency" => @other_token_hex, "owner" => bob_addr},
                     %{"amount" => 3, "currency" => @other_token_hex, "owner" => bob_addr}
                   ],
                   "fee" => %{"amount" => 5, "currency" => @eth_hex}
                 }
               )
    end

    defp balance_in_token(address, token) do
      currency = Encoding.to_hex(token)

      TestHelper.get_balance(address)
      |> Enum.find_value(0, fn
        %{"currency" => ^currency, "amount" => amount} -> amount
        _ -> false
      end)
    end

    defp max_amount_spendable_in_single_tx(address, token) do
      alias OMG.State.Transaction
      require Transaction
      currency = Encoding.to_hex(token)

      TestHelper.get_utxos(address)
      |> Stream.filter(&(&1["currency"] == currency))
      |> Enum.sort_by(& &1["amount"], &>=/2)
      |> Stream.take(Transaction.max_inputs())
      |> Stream.map(& &1["amount"])
      |> Enum.sum()
    end

    defp make_payments(blknum, spender, txs_bytes, blocks_inserter) when is_list(txs_bytes) do
      alias OMG.DevCrypto
      alias OMG.State.Transaction

      recovered_txs =
        txs_bytes
        |> Enum.map(fn "0x" <> tx ->
          {:ok, %Transaction.Recovered{} = recovered} =
            tx
            |> Base.decode16!(case: :lower)
            |> Transaction.decode!()
            |> DevCrypto.sign([spender.priv])
            |> Transaction.Signed.encode()
            |> Transaction.Recovered.recover_from()

          recovered
        end)

      [{blknum, recovered_txs}] |> blocks_inserter.()
    end
  end

  describe "creating transaction: Validation" do
    @tag fixtures: [:alice, :more_utxos]
    test "empty payments list attempted", %{alice: alice} do
      alice_addr = Encoding.to_hex(alice.addr)

      # NOTE: this is unintended behavior, there's a chore to fix this. Alter this test accordingly, when doing that.
      #       The intended behavior would be a relevant error message. For now testing non-crash at least:
      assert %{"result" => "complete"} =
               TestHelper.success?(
                 "transaction.create",
                 %{"owner" => alice_addr, "payments" => [], "fee" => %{"amount" => 0, "currency" => @eth_hex}}
               )
    end

    @tag fixtures: [:alice, :more_utxos]
    test "incorrect payment in payment list", %{alice: alice} do
      alice_addr = Encoding.to_hex(alice.addr)

      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "description" => "Parameters required by this operation are missing or incorrect.",
               "messages" => %{"validation_error" => %{"parameter" => "amount", "validator" => ":integer"}}
             } ==
               TestHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => alice_addr,
                   "payments" => [%{"amount" => "zonk", "currency" => @other_token_hex, "owner" => alice_addr}],
                   "fee" => %{"amount" => 0, "currency" => @eth_hex}
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
               TestHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => alice_addr,
                   "payments" => too_many_payments,
                   "fee" => %{"amount" => 0, "currency" => @eth_hex}
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
               TestHelper.no_success?(
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
               TestHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [],
                   "fee" => %{"amount" => 5, "currency" => @eth_hex},
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
               TestHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => "not-a-list",
                   "fee" => %{"amount" => 5, "currency" => @eth_hex}
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
                   "parameter" => "amount",
                   "validator" => "{:greater, -1}"
                 }
               }
             } ==
               TestHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => [],
                   "fee" => %{"amount" => -10, "currency" => @eth_hex}
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
                   "validator" => ":missing"
                 }
               }
             } ==
               TestHelper.no_success?(
                 "transaction.create",
                 %{
                   "owner" => Encoding.to_hex(alice.addr),
                   "payments" => []
                 }
               )
    end
  end
end
