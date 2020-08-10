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

defmodule OMG.WatcherRPC.Web.Validator.BlockConstraintsTest do
  use ExUnit.Case, async: true

  alias OMG.WatcherRPC.Web.Validator.BlockConstraints

  @valid_block %{
    "hash" => "0x" <> String.duplicate("00", 32),
    "number" => 1000,
    "transactions" => ["0x00"]
  }

  describe "parse/1" do
    test "returns page and limit constraints when given page and limit params" do
      request_data = %{"page" => 1, "limit" => 100}

      {:ok, constraints} = BlockConstraints.parse(request_data)
      assert constraints == [page: 1, limit: 100]
    end

    test "returns empty constraints when given no params" do
      request_data = %{}

      {:ok, constraints} = BlockConstraints.parse(request_data)
      assert constraints == []
    end

    test "returns a :validation_error when the given page == 0" do
      assert BlockConstraints.parse(%{"page" => 0}) == {:error, {:validation_error, "page", {:greater, 0}}}
    end

    test "returns a :validation_error when the given page < 0" do
      assert BlockConstraints.parse(%{"page" => -1}) == {:error, {:validation_error, "page", {:greater, 0}}}
    end

    test "returns a :validation_error when the given page is not an integer" do
      assert BlockConstraints.parse(%{"page" => 3.14}) == {:error, {:validation_error, "page", :integer}}
      assert BlockConstraints.parse(%{"page" => "abcd"}) == {:error, {:validation_error, "page", :integer}}
    end

    test "returns a :validation_error when the given limit == 0" do
      assert BlockConstraints.parse(%{"page" => 0}) == {:error, {:validation_error, "page", {:greater, 0}}}
    end

    test "returns a :validation_error when the given limit < 0" do
      assert BlockConstraints.parse(%{"page" => -1}) == {:error, {:validation_error, "page", {:greater, 0}}}
    end

    test "returns a :validation_error when the given limit is not an integer" do
      assert BlockConstraints.parse(%{"page" => 3.14}) == {:error, {:validation_error, "page", :integer}}
      assert BlockConstraints.parse(%{"page" => "abcd"}) == {:error, {:validation_error, "page", :integer}}
    end
  end

  describe "parse_to_validate/1" do
    test "rejects invalid Merkle root hash" do
      invalid_hash = "0x1234"
      invalid_block = Map.replace!(@valid_block, "hash", invalid_hash)

      assert {:error, {:validation_error, "hash", {:length, 32}}} ==
               BlockConstraints.parse_to_validate(invalid_block)
    end

    test "rejects non-list transactions parameter" do
      invalid_transactions_param = "0x1234"
      invalid_block = Map.replace!(@valid_block, "transactions", invalid_transactions_param)

      assert {:error, {:validation_error, "transactions", :list}} ==
               BlockConstraints.parse_to_validate(invalid_block)
    end

    test "rejects non-hex elements in transactions list" do
      invalid_tx_rlp = "0xZ"
      invalid_block = Map.replace!(@valid_block, "transactions", [invalid_tx_rlp])

      assert {:error, {:validation_error, "transactions.hash", :hex}} ==
               BlockConstraints.parse_to_validate(invalid_block)
    end

    test "rejects invalid block number parameter" do
      invalid_blknum = "ONE THOUSAND"
      invalid_block = Map.replace!(@valid_block, "number", invalid_blknum)

      assert {:error, {:validation_error, "number", :integer}} ==
               BlockConstraints.parse_to_validate(invalid_block)
    end
  end
end
