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

defmodule OMG.WatcherRPC.Web.Validator.BlockValidatorTest do
  use ExUnit.Case, async: true
  use OMG.WatcherRPC.Web, :controller

  alias OMG.Watcher.BlockValidator
  alias OMG.Watcher.Merkle
  alias OMG.Watcher.State.Transaction
  alias OMG.Watcher.TestHelper

  @alice TestHelper.generate_entity()
  @bob TestHelper.generate_entity()

  @eth <<0::160>>

  @payment_tx_type OMG.Watcher.WireFormatTypes.tx_type_for(:tx_payment_v1)

  @fee_claimer <<27::160>>
  @transaction_upper_limit 2 |> :math.pow(16) |> Kernel.trunc()

  describe "stateless_validate/1" do
    test "returns an error if a transaction within the block is not correctly formed (e.g. duplicate inputs in this test)" do
      input_1 = {1, 0, 0, @alice}
      input_2 = {2, 0, 0, @alice}
      input_3 = {3, 0, 0, @alice}

      signed_valid_tx = TestHelper.create_signed([input_1, input_2], @eth, [{@bob, 10}])
      signed_invalid_tx = TestHelper.create_signed([input_3, input_3], @eth, [{@bob, 10}])

      %{sigs: sigs_valid} = signed_valid_tx
      %{sigs: sigs_invalid} = signed_invalid_tx

      txbytes_valid = Transaction.raw_txbytes(signed_valid_tx)
      txbytes_invalid = Transaction.raw_txbytes(signed_invalid_tx)

      [_, inputs_valid, outputs_valid, _, _] = ExRLP.decode(txbytes_valid)
      [_, inputs_invalid, outputs_invalid, _, _] = ExRLP.decode(txbytes_invalid)

      hash_valid = ExRLP.encode([sigs_valid, @payment_tx_type, inputs_valid, outputs_valid, 0, <<0::256>>])

      hash_invalid =
        ExRLP.encode([
          sigs_invalid,
          @payment_tx_type,
          inputs_invalid,
          outputs_invalid,
          0,
          <<0::256>>
        ])

      block = %{
        hash: Merkle.hash([txbytes_valid, txbytes_invalid]),
        number: 1000,
        transactions: [hash_invalid, hash_valid]
      }

      assert {:error, :duplicate_inputs} == BlockValidator.stateless_validate(block)
    end

    test "accepts correctly formed transactions" do
      recovered_tx_1 = TestHelper.create_recovered([{1, 0, 0, @alice}, {2, 0, 0, @alice}], @eth, [{@bob, 10}])

      recovered_tx_2 = TestHelper.create_recovered([{3, 0, 0, @alice}, {4, 0, 0, @alice}], @eth, [{@bob, 10}])

      signed_txbytes_1 = recovered_tx_1.signed_tx_bytes
      signed_txbytes_2 = recovered_tx_2.signed_tx_bytes

      block = %{
        hash: derive_merkle_root([recovered_tx_1, recovered_tx_2]),
        number: 1000,
        transactions: [signed_txbytes_1, signed_txbytes_2]
      }

      assert {:ok, true} == BlockValidator.stateless_validate(block)
    end

    test "returns an error if the given hash does not match the reconstructed Merkle root hash" do
      recovered_tx_1 = TestHelper.create_recovered([{1, 0, 0, @alice}], @eth, [{@bob, 100}])
      recovered_tx_2 = TestHelper.create_recovered([{2, 0, 0, @alice}], @eth, [{@bob, 100}])

      signed_txbytes = Enum.map([recovered_tx_1, recovered_tx_2], fn tx -> tx.signed_tx_bytes end)

      block = %{
        hash: "0x0",
        number: 1000,
        transactions: signed_txbytes
      }

      assert {:error, :invalid_merkle_root} == BlockValidator.stateless_validate(block)
    end

    test "accepts a matching Merkle root hash" do
      recovered_tx_1 = TestHelper.create_recovered([{1, 0, 0, @alice}], @eth, [{@bob, 100}])
      recovered_tx_2 = TestHelper.create_recovered([{2, 0, 0, @alice}], @eth, [{@bob, 100}])

      signed_txbytes = Enum.map([recovered_tx_1, recovered_tx_2], fn tx -> tx.signed_tx_bytes end)

      valid_merkle_root = derive_merkle_root([recovered_tx_1, recovered_tx_2])

      block = %{
        hash: valid_merkle_root,
        number: 1000,
        transactions: signed_txbytes
      }

      assert {:ok, true} = BlockValidator.stateless_validate(block)
    end

    test "rejects a block with no transactions or more transactions than the defined limit" do
      oversize_block = %{
        hash: "0x0",
        number: 1000,
        transactions: List.duplicate("0x0", @transaction_upper_limit + 1)
      }

      undersize_block = %{
        hash: "0x0",
        number: 1000,
        transactions: []
      }

      assert {:error, :transactions_exceed_block_limit} = BlockValidator.stateless_validate(oversize_block)

      assert {:error, :empty_block} = BlockValidator.stateless_validate(undersize_block)
    end

    test "rejects a block that uses the same input in different transactions" do
      duplicate_input = {1, 0, 0, @alice}

      recovered_tx_1 = TestHelper.create_recovered([duplicate_input], @eth, [{@bob, 10}])
      recovered_tx_2 = TestHelper.create_recovered([duplicate_input], @eth, [{@bob, 10}])

      signed_txbytes_1 = recovered_tx_1.signed_tx_bytes
      signed_txbytes_2 = recovered_tx_2.signed_tx_bytes

      block = %{
        hash: derive_merkle_root([recovered_tx_1, recovered_tx_2]),
        number: 1000,
        transactions: [signed_txbytes_1, signed_txbytes_2]
      }

      assert {:error, :block_duplicate_inputs} == BlockValidator.stateless_validate(block)
    end
  end

  describe "stateless_validate/1 (fee validation)" do
    test "rejects a block if there are multiple fee transactions of the same currency" do
      input_1 = {1, 0, 0, @alice}
      input_2 = {2, 0, 0, @alice}

      payment_tx_1 = TestHelper.create_recovered([input_1], @eth, [{@bob, 10}])
      payment_tx_2 = TestHelper.create_recovered([input_2], @eth, [{@bob, 10}])
      fee_tx_1 = TestHelper.create_recovered_fee_tx(1, @fee_claimer, @eth, 1)
      fee_tx_2 = TestHelper.create_recovered_fee_tx(1, @fee_claimer, @eth, 1)

      signed_txbytes = Enum.map([payment_tx_1, payment_tx_2, fee_tx_1, fee_tx_2], fn tx -> tx.signed_tx_bytes end)

      block = %{
        hash: derive_merkle_root([payment_tx_1, payment_tx_2, fee_tx_1, fee_tx_2]),
        number: 1000,
        transactions: signed_txbytes
      }

      assert {:error, :duplicate_fee_transaction_for_ccy} = BlockValidator.stateless_validate(block)
    end

    test "rejects a block if fee transactions are not at the tail of the transactions' list (one fee currency)" do
      input_1 = {1, 0, 0, @alice}
      input_2 = {2, 0, 0, @alice}

      payment_tx_1 = TestHelper.create_recovered([input_1], @eth, [{@bob, 10}])
      payment_tx_2 = TestHelper.create_recovered([input_2], @eth, [{@bob, 10}])
      fee_tx = TestHelper.create_recovered_fee_tx(1, @fee_claimer, @eth, 5)

      invalid_ordered_transactions = [payment_tx_1, fee_tx, payment_tx_2]
      signed_txbytes = Enum.map(invalid_ordered_transactions, fn tx -> tx.signed_tx_bytes end)

      block = %{
        hash: derive_merkle_root(invalid_ordered_transactions),
        number: 1000,
        transactions: signed_txbytes
      }

      assert {:error, :unexpected_transaction_type_at_fee_index} = BlockValidator.stateless_validate(block)
    end

    test "rejects a block if fee transactions are not at the tail of the transactions' list (two fee currencies)" do
      ccy_1 = @eth
      ccy_2 = <<1::160>>

      ccy_1_fee = 1
      ccy_2_fee = 1

      input_1 = {1, 0, 0, @alice}
      input_2 = {2, 0, 0, @alice}

      payment_tx_1 = TestHelper.create_recovered([input_1], ccy_1, [{@bob, 10}])
      payment_tx_2 = TestHelper.create_recovered([input_2], ccy_2, [{@bob, 10}])

      fee_tx_1 = TestHelper.create_recovered_fee_tx(1, @fee_claimer, ccy_1, ccy_1_fee)
      fee_tx_2 = TestHelper.create_recovered_fee_tx(1, @fee_claimer, ccy_2, ccy_2_fee)

      invalid_ordered_transactions = [payment_tx_1, fee_tx_1, payment_tx_2, fee_tx_2]
      signed_txbytes = Enum.map(invalid_ordered_transactions, fn tx -> tx.signed_tx_bytes end)

      block = %{
        hash: derive_merkle_root(invalid_ordered_transactions),
        number: 1000,
        transactions: signed_txbytes
      }

      assert {:error, :unexpected_transaction_type_at_fee_index} = BlockValidator.stateless_validate(block)
    end
  end

  @spec derive_merkle_root([Transaction.Recovered.t()]) :: binary()
  defp(derive_merkle_root(transactions)) do
    transactions |> Enum.map(&Transaction.raw_txbytes/1) |> Merkle.hash()
  end
end
