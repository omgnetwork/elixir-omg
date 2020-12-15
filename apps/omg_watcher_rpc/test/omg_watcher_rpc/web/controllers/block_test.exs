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

defmodule OMG.WatcherRPC.Web.Controller.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.WatcherInfo.Fixtures
  use OMG.WatcherRPC.Web, :controller

  import OMG.WatcherInfo.Factory

  alias OMG.Eth.Encoding
  alias OMG.Merkle
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.WireFormatTypes

  alias Support.WatcherHelper

  @valid_block %{
    hash: "0x" <> String.duplicate("00", 32),
    number: 1000,
    transactions: ["0x00"]
  }
  @eth OMG.Eth.zero_address()
  @alice OMG.TestHelper.generate_entity()
  @bob OMG.TestHelper.generate_entity()
  @payment_tx_type WireFormatTypes.tx_type_for(:tx_payment_v1)

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
        "messages" => %{
          "validation_error" => %{"parameter" => "blknum", "validator" => ":integer"}
        },
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
        "messages" => %{
          "validation_error" => %{"parameter" => "blknum", "validator" => ":integer"}
        },
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
    test "returns the error API response if a parameter is incorectly formed" do
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
    test "returns the expected error if the block hash does not match the reconstructed Merkle root" do
      recovered_tx_1 = TestHelper.create_recovered([{1, 0, 0, @alice}], @eth, [{@bob, 100}])
      recovered_tx_2 = TestHelper.create_recovered([{2, 0, 0, @alice}], @eth, [{@bob, 100}])

      signed_txbytes =
        [recovered_tx_1, recovered_tx_2]
        |> Enum.map(fn tx -> tx.signed_tx_bytes end)
        |> Enum.map(&Encoding.to_hex/1)

      invalid_merkle_root = "0x" <> String.duplicate("00", 32)

      params = %{
        hash: invalid_merkle_root,
        number: 1000,
        transactions: signed_txbytes
      }

      %{"data" => data} = WatcherHelper.rpc_call("block.validate", params, 200)

      assert data == %{"valid" => false}
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns the expected error if the transactions are incorrectly formed" do
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

      hash_valid =
        [sigs_valid, @payment_tx_type, inputs_valid, outputs_valid, 0, <<0::256>>]
        |> ExRLP.encode()
        |> Encoding.to_hex()

      hash_invalid =
        [sigs_invalid, @payment_tx_type, inputs_invalid, outputs_invalid, 0, <<0::256>>]
        |> ExRLP.encode()
        |> Encoding.to_hex()

      merkle_root = [txbytes_invalid, txbytes_valid] |> Merkle.hash() |> Encoding.to_hex()

      params = %{
        hash: merkle_root,
        transactions: [hash_invalid, hash_valid],
        number: 1000
      }

      # Sanity check
      assert {:ok, Encoding.from_hex(merkle_root)} == expect(%{hash: merkle_root}, :hash, :hash)

      %{"data" => data} = WatcherHelper.rpc_call("block.validate", params, 200)

      assert data == %{"valid" => false}
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns the block if it is valid" do
      recovered_tx_1 = TestHelper.create_recovered([{1, 0, 0, @alice}], @eth, [{@bob, 100}])
      recovered_tx_2 = TestHelper.create_recovered([{2, 0, 0, @alice}], @eth, [{@bob, 100}])

      signed_txbytes =
        [recovered_tx_1, recovered_tx_2]
        |> Enum.map(fn tx -> tx.signed_tx_bytes end)
        |> Enum.map(&Encoding.to_hex/1)

      valid_merkle_root =
        [recovered_tx_1, recovered_tx_2]
        |> Enum.map(&Transaction.raw_txbytes/1)
        |> Merkle.hash()
        |> Encoding.to_hex()

      # Sanity check
      assert {:ok, Encoding.from_hex(valid_merkle_root)} == expect(%{hash: valid_merkle_root}, :hash, :hash)

      params = %{
        hash: valid_merkle_root,
        number: 1000,
        transactions: signed_txbytes
      }

      %{"data" => data} = WatcherHelper.rpc_call("block.validate", params, 200)

      assert data == %{"valid" => true}
    end
  end
end
