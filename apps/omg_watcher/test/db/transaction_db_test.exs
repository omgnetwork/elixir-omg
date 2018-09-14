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

defmodule OMG.Watcher.DB.TransactionDBTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures
  use Plug.Test

  alias OMG.API.Block
  alias OMG.API.Crypto
  alias OMG.API.State.Transaction.{Recovered, Signed}
  alias OMG.API.Utxo
  alias OMG.Watcher.DB.TransactionDB
  alias OMG.Watcher.DB.TxOutputDB

  require Utxo

  @eth Crypto.zero_address()

  describe "Transaction database" do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
    test "insert and retrive transaction", %{alice: alice, bob: bob} do
      tester_f = fn {blknum, recovered_txs} ->
        db_results = TransactionDB.update_with(%Block{transactions: recovered_txs, number: blknum})
        assert db_results |> Enum.all?(&(elem(&1, 0) == :ok))

        recovered_txs
        |> Enum.with_index()
        |> Enum.map(fn {recovered_tx, txindex} ->
          txhash = recovered_tx.signed_tx_hash
          expected_transaction = create_expected_transaction(txhash, recovered_tx, blknum, txindex)
          assert expected_transaction == delete_meta(TransactionDB.get(txhash))
        end)
      end

      [
        {1000,
         [
           OMG.API.TestHelper.create_recovered([], @eth, [{alice, 300}]),
           OMG.API.TestHelper.create_recovered([{1000, 0, 0, alice}], @eth, [{alice, 100}, {bob, 200}])
         ]},
        {2000, [OMG.API.TestHelper.create_recovered([{1000, 1, 0, alice}], @eth, [{bob, 50}, {alice, 50}])]},
        {3000,
         [
           OMG.API.TestHelper.create_recovered([{2000, 0, 1, alice}, {1000, 1, 1, bob}], @eth, [
             {alice, 150},
             {bob, 100}
           ]),
           OMG.API.TestHelper.create_recovered([{3000, 0, 1, bob}, {3000, 0, 0, alice}], @eth, [{bob, 250}])
         ]}
      ]
      |> Enum.map(tester_f)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
    test "insert and retrive block of transactions ", %{alice: alice, bob: bob} do
      blknum = 0
      recovered_tx1 = OMG.API.TestHelper.create_recovered([{2, 3, 1, bob}], @eth, [{alice, 200}])
      recovered_tx2 = OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 100}])

      [{:ok, %TransactionDB{txhash: txhash_1}}, {:ok, %TransactionDB{txhash: txhash_2}}] =
        TransactionDB.update_with(%Block{
          transactions: [
            recovered_tx1,
            recovered_tx2
          ],
          number: blknum
        })

      assert create_expected_transaction(txhash_1, recovered_tx1, blknum, 0) == delete_meta(TransactionDB.get(txhash_1))
      assert create_expected_transaction(txhash_2, recovered_tx2, blknum, 1) == delete_meta(TransactionDB.get(txhash_2))
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
    test "gets all transactions from a block", %{alice: alice, bob: bob} do
      blknum = 1000
      assert [] == TransactionDB.get_by_blknum(blknum)

      alice_spend_recovered = OMG.API.TestHelper.create_recovered([], @eth, [{alice, 100}])
      bob_spend_recovered = OMG.API.TestHelper.create_recovered([], @eth, [{bob, 200}])

      [{:ok, %TransactionDB{txhash: txhash_alice}}, {:ok, %TransactionDB{txhash: txhash_bob}}] =
        TransactionDB.update_with(%Block{
          transactions: [alice_spend_recovered, bob_spend_recovered],
          number: blknum
        })

      assert [
               create_expected_transaction(txhash_alice, alice_spend_recovered, blknum, 0),
               create_expected_transaction(txhash_bob, bob_spend_recovered, blknum, 1)
             ] == blknum |> TransactionDB.get_by_blknum() |> Enum.map(&delete_meta/1)
    end

    @tag :olol
    @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
    test "gets transaction that spends utxo", %{alice: alice, bob: bob} do
      alice_deposit_pos = Utxo.position(1, 0, 0)
      bob_deposit_pos = Utxo.position(2, 0, 0)
      alice_addr = alice.addr
      bob_addr = bob.addr

      OMG.Watcher.DB.EthEventDB.insert_deposits([
        %{owner: alice_addr, currency: @eth, amount: 100, blknum: 1, hash: "hash1"},
        %{owner: bob_addr, currency: @eth, amount: 100, blknum: 2, hash: "hash2"}
      ])

      {:error, :utxo_not_spent} = TransactionDB.get_transaction_challenging_utxo(alice_deposit_pos)
      {:error, :utxo_not_spent} = TransactionDB.get_transaction_challenging_utxo(bob_deposit_pos)

      alice_spend_recovered = OMG.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 99}])

      [{:ok, %TransactionDB{txhash: txhash_alice}}] =
        TransactionDB.update_with(%Block{
          transactions: [alice_spend_recovered],
          number: 1000
        })

      assert match?(
               %TransactionDB{
                 txhash: txhash_alice,
                 blknum: 1000,
                 txindex: 0,
                 inputs: [%TxOutputDB{creating_deposit: "hash1", owner: alice_addr, currency: @eth, amount: 100}],
                 outputs: [%TxOutputDB{creating_txhash: txhash_alice, owner: bob_addr, currency: @eth, amount: 99}]
               },
               delete_meta(TransactionDB.get_transaction_challenging_utxo(alice_deposit_pos))
             )

      {:error, :utxo_not_spent} = TransactionDB.get_transaction_challenging_utxo(bob_deposit_pos)

      bob_spend_recovered = OMG.API.TestHelper.create_recovered([{2, 0, 0, bob}], @eth, [{alice, 99}])

      [{:ok, %TransactionDB{txhash: txhash_bob}}] =
        TransactionDB.update_with(%Block{
          transactions: [bob_spend_recovered],
          number: 2000
        })

      assert match?(
               %TransactionDB{
                 txhash: txhash_bob,
                 blknum: 2000,
                 txindex: 0,
                 inputs: [%TxOutputDB{creating_deposit: "hash2", owner: bob_addr, currency: @eth, amount: 100}],
                 outputs: [%TxOutputDB{creating_txhash: txhash_bob, owner: alice_addr, currency: @eth, amount: 99}]
               },
               delete_meta(TransactionDB.get_transaction_challenging_utxo(bob_deposit_pos))
             )
    end

    defp create_expected_transaction(
           txhash,
           %Recovered{signed_tx: %Signed{} = signed_tx},
           blknum,
           txindex
         ) do
      %TransactionDB{
        blknum: blknum,
        txindex: txindex,
        txhash: txhash,
        txbytes: Signed.encode(signed_tx)
      }
      |> delete_meta()
    end

    defp delete_meta(%TransactionDB{} = transaction) do
      Map.delete(transaction, :__meta__)
    end

    defp delete_meta({:ok, %TransactionDB{} = transaction}) do
      delete_meta(transaction)
    end
  end
end
