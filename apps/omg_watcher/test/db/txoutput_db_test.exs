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

defmodule OMG.Watcher.DB.TxOutputDBTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures

  alias OMG.API
  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.Watcher.DB.EthEventDB
  alias OMG.Watcher.DB.TransactionDB
  alias OMG.Watcher.DB.TxOutputDB

  require Utxo

  @eth Crypto.zero_address()

  describe "TxOutput database" do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "compose_utxo_exit should return proper proof format", %{alice: alice} do
      TransactionDB.update_with(%{
        transactions: [
          API.TestHelper.create_recovered([], @eth, [{alice, 120}]),
          API.TestHelper.create_recovered([], @eth, [{alice, 110}]),
          API.TestHelper.create_recovered([], @eth, [{alice, 100}])
        ],
        blknum: 1000,
        eth_height: 1
      })

      {:ok,
       %{
         utxo_pos: _utxo_pos,
         txbytes: _txbytes,
         proof: proof,
         sigs: _sigs
       }} = TxOutputDB.compose_utxo_exit(Utxo.position(1000, 1, 0))

      assert <<_proof::bytes-size(512)>> = proof
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "compose_utxo_exit should return error when there is no txs in specfic block" do
      {:error, :no_tx_for_given_blknum} = TxOutputDB.compose_utxo_exit(Utxo.position(1, 1, 0))
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "compose_utxo_exit should return error when there is no tx in specfic block", %{alice: alice} do
      TransactionDB.update_with(%{
        transactions: [
          API.TestHelper.create_recovered([], @eth, [{alice, 120}]),
          API.TestHelper.create_recovered([], @eth, [{alice, 110}]),
          API.TestHelper.create_recovered([], @eth, [{alice, 100}])
        ],
        blknum: 1000,
        eth_height: 1
      })

      {:error, :no_tx_for_given_blknum} = TxOutputDB.compose_utxo_exit(Utxo.position(1000, 3, 0))
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "transaction output schema handles big numbers properly", %{alice: alice} do
      power_of_2 = fn n -> :lists.duplicate(n, 2) |> Enum.reduce(&(&1 * &2)) end
      assert 16 == power_of_2.(4)

      # TODO: sqlite does not support decimals, run tests agains real db, then change the exponent to 260
      big_amount = power_of_2.(50)

      TransactionDB.update_with(%{
        transactions: [
          API.TestHelper.create_recovered([], @eth, [{alice, big_amount}])
        ],
        blknum: 1000,
        eth_height: 1
      })

      utxo = TxOutputDB.get_by_position(Utxo.position(1000, 0, 0))
      assert not is_nil(utxo)
      assert utxo.amount == big_amount
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "utxo can be found by deposit position regardless block number", %{alice: alice} do
      EthEventDB.insert_deposits([
        %{blknum: 1, owner: alice.addr, currency: @eth, amount: 1, hash: "hash1"},
        %{blknum: 1000, owner: alice.addr, currency: @eth, amount: 2, hash: "hash2"},
        %{blknum: 2013, owner: alice.addr, currency: @eth, amount: 3, hash: "hash3"}
      ])

      alice_addr = alice.addr

      assert %TxOutputDB{
               owner: ^alice_addr,
               currency: @eth,
               amount: 1,
               creating_deposit: "hash1",
               creating_txhash: nil,
               creating_tx_oindex: 0
             } = TxOutputDB.get_by_position(Utxo.position(1, 0, 0))

      assert %TxOutputDB{
               owner: ^alice_addr,
               currency: @eth,
               amount: 2,
               creating_deposit: "hash2",
               creating_txhash: nil,
               creating_tx_oindex: 0
             } = TxOutputDB.get_by_position(Utxo.position(1000, 0, 0))

      assert %TxOutputDB{
               owner: ^alice_addr,
               currency: @eth,
               amount: 3,
               creating_deposit: "hash3",
               creating_txhash: nil,
               creating_tx_oindex: 0
             } = TxOutputDB.get_by_position(Utxo.position(2013, 0, 0))
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "utxo can be found by transaction position regardless block number", %{alice: alice} do
      alice_addr = alice.addr

      [{:ok, %TransactionDB{txhash: txhash1}}] =
        TransactionDB.update_with(%{
          transactions: [API.TestHelper.create_recovered([], @eth, [{alice, 1}])],
          blknum: 1,
          eth_height: 1
        })

      assert %TxOutputDB{
               owner: ^alice_addr,
               currency: @eth,
               amount: 1,
               creating_deposit: nil,
               creating_txhash: ^txhash1,
               creating_tx_oindex: 0
             } = TxOutputDB.get_by_position(Utxo.position(1, 0, 0))

      [{:ok, _tx0}, {:ok, %TransactionDB{txhash: txhash2}}] =
        TransactionDB.update_with(%{
          transactions: [
            API.TestHelper.create_recovered([], @eth, [{alice, 10_001}]),
            API.TestHelper.create_recovered([], @eth, [{alice, 1}, {alice, 2}])
          ],
          blknum: 1000,
          eth_height: 1
        })

      assert %TxOutputDB{
               owner: ^alice_addr,
               currency: @eth,
               amount: 2,
               creating_deposit: nil,
               creating_txhash: ^txhash2,
               creating_tx_oindex: 1
             } = TxOutputDB.get_by_position(Utxo.position(1000, 1, 1))

      [{:ok, _tx0}, {:ok, _tx1}, {:ok, %TransactionDB{txhash: txhash3}}] =
        TransactionDB.update_with(%{
          transactions: [
            API.TestHelper.create_recovered([], @eth, [{alice, 20_131}]),
            API.TestHelper.create_recovered([], @eth, [{alice, 20_132}]),
            API.TestHelper.create_recovered([], @eth, [{alice, 3}, {alice, 4}])
          ],
          blknum: 2013,
          eth_height: 1
        })

      assert %TxOutputDB{
               owner: ^alice_addr,
               currency: @eth,
               amount: 3,
               creating_deposit: nil,
               creating_txhash: ^txhash3,
               creating_tx_oindex: 0
             } = TxOutputDB.get_by_position(Utxo.position(2013, 2, 0))
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "create outputs: creates proper transaction's outputs" do
      newowner1 = <<1::160>>
      amount1 = 1
      newowner2 = <<2::160>>
      amount2 = 2

      tx = %Transaction{cur12: @eth, newowner1: newowner1, amount1: amount1, newowner2: newowner2, amount2: amount2}

      [utxo1, utxo2] = TxOutputDB.create_outputs(tx)

      assert %TxOutputDB{owner: newowner1, amount: amount1, currency: @eth, creating_tx_oindex: 0} == utxo1

      assert %TxOutputDB{owner: newowner2, amount: amount2, currency: @eth, creating_tx_oindex: 1} == utxo2
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "create outputs: output with zero amount is skipped" do
      newowner1 = <<1::160>>
      amount1 = 1
      newowner2 = <<0::160>>
      amount2 = 0

      tx = %Transaction{cur12: @eth, newowner1: newowner1, amount1: amount1, newowner2: newowner2, amount2: amount2}

      [utxo1] = TxOutputDB.create_outputs(tx)

      assert %TxOutputDB{owner: newowner1, amount: amount1, currency: @eth, creating_tx_oindex: 0} == utxo1
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "get inputs: prepares existing utxo for spend", %{alice: alice} do
      [{:ok, _evnt}] =
        EthEventDB.insert_deposits([%{blknum: 1, owner: alice.addr, currency: @eth, amount: 1, hash: "hash1"}])

      tx = %Transaction{blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0}
      [changeset] = TxOutputDB.get_inputs(tx)

      assert %Ecto.Changeset{
               data: %TxOutputDB{creating_deposit: "hash1", spending_tx_oindex: nil},
               changes: %{spending_tx_oindex: 0}
             } = changeset
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "get inputs: providing non-existing utxo position results in empty list" do
      tx = %Transaction{blknum1: 111, txindex1: 0, oindex1: 11, blknum2: 0, txindex2: 10, oindex2: 3}

      assert [] == TxOutputDB.get_inputs(tx)
    end
  end
end
