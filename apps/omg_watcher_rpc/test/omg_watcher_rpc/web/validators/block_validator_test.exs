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

defmodule OMG.WatcherRPC.Web.Validator.BlockValidatorTest do
  use ExUnit.Case, async: true
  use OMG.WatcherRPC.Web, :controller

  alias OMG.Merkle
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.WatcherRPC.Web.Validator.BlockValidator
  alias OMG.WireFormatTypes

  @alice OMG.TestHelper.generate_entity()
  @bob OMG.TestHelper.generate_entity()
  @eth OMG.Eth.zero_address()
  @payment_tx_type WireFormatTypes.tx_type_for(:tx_payment_v1)
  @valid_block %{
    "hash" => "0x" <> String.duplicate("00", 32),
    "number" => 1000,
    "transactions" => ["0x00"]
  }

  describe "parse_to_validate/1" do
    test "rejects invalid Merkle root hash" do
      invalid_hash = "0x1234"
      invalid_block = Map.replace!(@valid_block, "hash", invalid_hash)

      assert {:error, {:validation_error, "hash", {:length, 32}}} ==
               BlockValidator.parse_to_validate(invalid_block)
    end

    test "rejects non-list transactions parameter" do
      invalid_transactions_param = "0x1234"
      invalid_block = Map.replace!(@valid_block, "transactions", invalid_transactions_param)

      assert {:error, {:validation_error, "transactions", :list}} ==
               BlockValidator.parse_to_validate(invalid_block)
    end

    test "rejects non-hex elements in transactions list" do
      invalid_tx_rlp = "0xZ"
      invalid_block = Map.replace!(@valid_block, "transactions", [invalid_tx_rlp])

      assert {:error, {:validation_error, "transactions.hash", :hex}} ==
               BlockValidator.parse_to_validate(invalid_block)
    end

    test "rejects invalid block number parameter" do
      invalid_blknum = "ONE THOUSAND"
      invalid_block = Map.replace!(@valid_block, "number", invalid_blknum)

      assert {:error, {:validation_error, "number", :integer}} ==
               BlockValidator.parse_to_validate(invalid_block)
    end
  end

  describe "verify_transactions/1" do
    test "returns error if a transaction is not correctly formed (duplicate inputs in this example)" do
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
      hash_invalid = ExRLP.encode([sigs_invalid, @payment_tx_type, inputs_invalid, outputs_invalid, 0, <<0::256>>])

      assert {:error, :duplicate_inputs} ==
               BlockValidator.verify_transactions([hash_invalid, hash_valid])
    end

    test "accepts correctly formed transactions" do
      recovered_tx_1 = TestHelper.create_recovered([{1, 0, 0, @alice}, {2, 0, 0, @alice}], @eth, [{@bob, 10}])
      recovered_tx_2 = TestHelper.create_recovered([{3, 0, 0, @alice}, {4, 0, 0, @alice}], @eth, [{@bob, 10}])

      signed_txbytes_1 = recovered_tx_1.signed_tx_bytes
      signed_txbytes_2 = recovered_tx_2.signed_tx_bytes

      {:ok, expected_1} = Transaction.Recovered.recover_from(signed_txbytes_1)
      {:ok, expected_2} = Transaction.Recovered.recover_from(signed_txbytes_2)

      assert {:ok, [expected_1, expected_2]} ==
               BlockValidator.verify_transactions([signed_txbytes_1, signed_txbytes_2])
    end
  end

  describe "verify_merkle_root/1" do
    test "returns error for non-matching Merkle root hash" do
      recovered_tx_1 = TestHelper.create_recovered([{1, 0, 0, @alice}], @eth, [{@bob, 100}])
      recovered_tx_2 = TestHelper.create_recovered([{2, 0, 0, @alice}], @eth, [{@bob, 100}])

      signed_txbytes = Enum.map([recovered_tx_1, recovered_tx_2], & &1.signed_tx_bytes)

      block = %{
        hash: "0x0",
        number: 1000,
        transactions: signed_txbytes
      }

      assert {:error, :invalid_merkle_root} == BlockValidator.verify_merkle_root(block)
    end

    test "accepts matching Merkle root hash" do
      recovered_tx_1 = TestHelper.create_recovered([{1, 0, 0, @alice}], @eth, [{@bob, 100}])
      recovered_tx_2 = TestHelper.create_recovered([{2, 0, 0, @alice}], @eth, [{@bob, 100}])

      signed_txbytes = Enum.map([recovered_tx_1, recovered_tx_2], & &1.signed_tx_bytes)

      valid_merkle_root =
        [recovered_tx_1, recovered_tx_2]
        |> Enum.map(&Transaction.raw_txbytes/1)
        |> Merkle.hash()

      block = %{
        hash: valid_merkle_root,
        number: 1000,
        transactions: signed_txbytes
      }

      assert {:ok, block} = BlockValidator.verify_merkle_root(block)
    end
  end
end
