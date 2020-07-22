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

defmodule OMG.WatcherRPC.Web.Controller.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.WatcherInfo.Fixtures

  import OMG.WatcherInfo.Factory

  alias Support.WatcherHelper
  alias OMG.DevCrypto
  alias OMG.State.Transaction
  alias OMG.WireFormatTypes
  alias OMG.Eth.Encoding
  alias OMG.WatcherRPC.Web.Controller.Block

  @payment_tx_type WireFormatTypes.tx_type_for(:tx_payment_v1)
  @eth OMG.Eth.zero_address()
  @valid_block %{
    hash: "0x" <> String.duplicate("00", 32),
    number: 1000,
    transactions: ["0xf8c0f843b841fc6dbf49a4baa783ec576291f6083be5ea3dd4b5f2f5e2c1fc2bb1a50fbda4b81d9b147c7a0199f39c705f90de2be790adfbded38e8ef7a0032e4aa591a5b3b51b01e1a000000000000000000000000000000000000000000000000000000000b2d05e00f5f401f294d42b31665b93c128541c8b89a0e545afb08b7dd894000000000000000000000000000000000000000087038d7ea4c67fff80a00000000000000000000000000000000000000000000000000000000000001337"]
  }

  describe "get_block/2" do
    @tag fixtures: [:initial_blocks]
    test "/block.get returns correct block if existent" do
      existent_blknum = 1000

      %{"success" => success, "data" => data} = WatcherHelper.rpc_call("block.get", %{blknum: existent_blknum}, 200)

      assert data["blknum"] == existent_blknum
      assert success == true
    end

    @tag fixtures: [:initial_blocks]
    test "/block.get rejects parameter of wrong type" do
      string_blknum = "1000"
      %{"data" => data} = WatcherHelper.rpc_call("block.get", %{blknum: string_blknum}, 200)

      expected = %{
        "code" => "operation:bad_request",
        "description" => "Parameters required by this operation are missing or incorrect.",
        "messages" => %{"validation_error" => %{"parameter" => "blknum", "validator" => ":integer"}},
        "object" => "error"
      }

      assert data == expected
    end

    @tag fixtures: [:initial_blocks]
    test "/block.get endpoint rejects request without parameters" do
      missing_param = %{}
      %{"data" => data} = WatcherHelper.rpc_call("block.get", missing_param, 200)

      expected = %{
        "code" => "operation:bad_request",
        "description" => "Parameters required by this operation are missing or incorrect.",
        "messages" => %{"validation_error" => %{"parameter" => "blknum", "validator" => ":integer"}},
        "object" => "error"
      }

      assert data == expected
    end

    @tag fixtures: [:initial_blocks]
    test "/block.get returns expected error if block not found" do
      non_existent_block = 5000
      %{"data" => data} = WatcherHelper.rpc_call("block.get", %{blknum: non_existent_block}, 200)

      expected = %{
        "code" => "get_block:block_not_found",
        "description" => nil,
        "object" => "error"
      }

      assert data == expected
    end
  end

  describe "get_blocks/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns the API response with the blocks" do
      _ = insert(:block, blknum: 1000, hash: <<1>>, eth_height: 1, timestamp: 100)
      _ = insert(:block, blknum: 2000, hash: <<2>>, eth_height: 2, timestamp: 200)

      request_data = %{"limit" => 200, "page" => 1}
      response = WatcherHelper.rpc_call("block.all", request_data, 200)

      assert %{
               "success" => true,
               "data" => [
                 %{
                   "blknum" => 2000,
                   "eth_height" => 2,
                   "hash" => "0x02",
                   "timestamp" => 200,
                   "tx_count" => 0
                 },
                 %{
                   "blknum" => 1000,
                   "eth_height" => 1,
                   "hash" => "0x01",
                   "timestamp" => 100,
                   "tx_count" => 0
                 }
               ],
               "data_paging" => %{
                 "limit" => 100,
                 "page" => 1
               },
               "service_name" => _,
               "version" => _
             } = response
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns the error API response when an error occurs" do
      request_data = %{"limit" => "this should error", "page" => 1}
      response = WatcherHelper.rpc_call("block.all", request_data, 200)

      assert %{
               "success" => false,
               "data" => %{
                 "object" => "error",
                 "code" => "operation:bad_request",
                 "description" => "Parameters required by this operation are missing or incorrect.",
                 "messages" => _
               },
               "service_name" => _,
               "version" => _
             } = response
    end
  end

  describe "validate_block/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "rejects invalid 'hash' parameter" do
      invalid_hash = "0x1234"
      invalid_params = Map.replace!(@valid_block, :hash, invalid_hash)

      %{"data" => data} = WatcherHelper.rpc_call("block.validate", invalid_params, 200)

      expected = %{
        "code" => "operation:bad_request",
        "description" => "Parameters required by this operation are missing or incorrect.",
        "messages" => %{
          "validation_error" => %{
            "parameter" => "hash",
            "validator" => "{:length, 32}"
          }
        },
        "object" => "error"
      }

      assert expected == data
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "rejects non-list 'transactions' parameter" do
      invalid_transactions_param = "0x1234"
      invalid_params = Map.replace!(@valid_block, :transactions, invalid_transactions_param)

      %{"data" => data} = WatcherHelper.rpc_call("block.validate", invalid_params, 200)

      expected = %{
        "code" => "operation:bad_request",
        "description" => "Parameters required by this operation are missing or incorrect.",
        "messages" => %{
          "validation_error" => %{
            "parameter" => "transactions",
            "validator" => ":list"
          }
        },
        "object" => "error"
      }

      assert expected == data
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "rejects invalid list elements in 'transactions' parameter" do
      invalid_tx_rlp = "0xZ"
      invalid_params = Map.replace!(@valid_block, :transactions, [invalid_tx_rlp])

      %{"data" => data} = WatcherHelper.rpc_call("block.validate", invalid_params, 200)

      expected = %{
        "code" => "operation:bad_request",
        "description" => "Parameters required by this operation are missing or incorrect.",
        "messages" => %{
          "validation_error" => %{
            "parameter" => "transactions.hash",
            "validator" => ":hex"
          }
        },
        "object" => "error"
      }

      assert expected == data
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "rejects invalid block number parameter" do
      invalid_blknum = "1000"
      invalid_params = Map.replace!(@valid_block, :number, invalid_blknum)

      %{"data" => data} = WatcherHelper.rpc_call("block.validate", invalid_params, 200)

      expected = %{
        "code" => "operation:bad_request",
        "description" => "Parameters required by this operation are missing or incorrect.",
        "messages" => %{
          "validation_error" => %{
            "parameter" => "number",
            "validator" => ":integer"
          }
        },
        "object" => "error"
      }

      assert expected == data
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "rejects unmatched merkle root hash" do
      %{"data" => data} = WatcherHelper.rpc_call("block.validate", @valid_block, 200)

      IO.inspect(data)
    end
  end

  describe "verify_transactions/1" do
    test "returns error if a transaction is not correctly formed (duplicate inputs in this example)" do
      %{priv: alice_private_key, addr: alice_address} = OMG.TestHelper.generate_entity()

      input_1 = {1, 0, 0}
      input_2 = {2, 0, 0}

      valid_payment = Transaction.Payment.new([input_1, input_2], [{alice_address, @eth, 12}])
      invalid_payment = Transaction.Payment.new([input_1, input_1], [{alice_address, @eth, 12}])

      signed_valid_tx = DevCrypto.sign(valid_payment, [alice_private_key, alice_private_key])
      signed_invalid_tx = DevCrypto.sign(invalid_payment, [alice_private_key, alice_private_key])

      %{sigs: sigs_valid} = signed_valid_tx
      %{sigs: sigs_invalid} = signed_invalid_tx

      txbytes_valid = Transaction.raw_txbytes(signed_valid_tx)
      txbytes_invalid = Transaction.raw_txbytes(signed_invalid_tx)

      [_, inputs_valid, outputs_valid, _, _] = ExRLP.decode(txbytes_valid)
      [_, inputs_invalid, outputs_invalid, _, _] = ExRLP.decode(txbytes_invalid)

      hash_invalid =
        [sigs_invalid, @payment_tx_type, inputs_invalid, outputs_invalid, 0, <<0::256>>]
        |> ExRLP.encode()
        |> Encoding.to_hex()

      hash_valid =
        [sigs_valid, @payment_tx_type, inputs_valid, outputs_valid, 0, <<0::256>>]
        |> ExRLP.encode()
        |> Encoding.to_hex()

      assert {:error, :duplicate_inputs} == Block.verify_transactions([hash_invalid, hash_valid])
    end

    test "accepts correctly formed transactions" do
      %{priv: alice_private_key, addr: alice_address} = OMG.TestHelper.generate_entity()

      input_1 = {1, 0, 0}
      input_2 = {2, 0, 0}
      input_3 = {3, 0, 0}
      input_4 = {4, 0, 0}

      payment_1 = Transaction.Payment.new([input_1, input_2], [{alice_address, @eth, 12}])
      payment_2 = Transaction.Payment.new([input_3, input_4], [{alice_address, @eth, 12}])

      signed_tx_1 = DevCrypto.sign(payment_1, [alice_private_key, alice_private_key])
      signed_tx_2 = DevCrypto.sign(payment_2, [alice_private_key, alice_private_key])

      %{sigs: sigs_1} = signed_tx_1
      %{sigs: sigs_2} = signed_tx_2

      txbytes_1 = Transaction.raw_txbytes(signed_tx_1)
      txbytes_2 = Transaction.raw_txbytes(signed_tx_2)

      [_, inputs_1, outputs_1, _, _] = ExRLP.decode(txbytes_1)
      [_, inputs_2, outputs_2, _, _] = ExRLP.decode(txbytes_2)

      hash_1 =
        [sigs_1, @payment_tx_type, inputs_1, outputs_1, 0, <<0::256>>]
        |> ExRLP.encode()
        |> Encoding.to_hex()

      hash_2 =
        [sigs_2, @payment_tx_type, inputs_2, outputs_2, 0, <<0::256>>]
        |> ExRLP.encode()
        |> Encoding.to_hex()

      {:ok, expected_1} = hash_1 |> Encoding.from_hex() |> Transaction.Recovered.recover_from()
      {:ok, expected_2} = hash_2 |> Encoding.from_hex() |> Transaction.Recovered.recover_from()

      assert {:ok, [expected_1, expected_2]} == Block.verify_transactions([hash_1, hash_2])
    end
  end
end
