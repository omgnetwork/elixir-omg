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

defmodule OMG.WatcherRPC.Web.Validator.TransactionConstraintsTest do
  use ExUnit.Case, async: true

  alias OMG.Eth.Encoding
  alias OMG.WatcherRPC.Web.Validator.TransactionConstraints

  @eth <<0::160>>
  @zero_metadata <<0::256>>

  describe "parse/1" do
    test "returns page and limit constraints when given page and limit params" do
      request_data = %{"page" => 1, "limit" => 100}

      {:ok, constraints} = TransactionConstraints.parse(request_data)
      assert constraints == [page: 1, limit: 100]
    end

    test "returns supported constraints when given" do
      request_data = %{
        "address" => Encoding.to_hex(@eth),
        "blknum" => 1000,
        "metadata" => Encoding.to_hex(@zero_metadata),
        "txtypes" => [1, 3],
        "end_datetime" => 12_345_678
      }

      {:ok, constraints} = TransactionConstraints.parse(request_data)

      assert constraints == [
               end_datetime: 12_345_678,
               txtypes: [1, 3],
               metadata: @zero_metadata,
               blknum: 1000,
               address: @eth
             ]
    end

    test "filters unsupported constraints" do
      request_data = %{
        "something" => "123"
      }

      {:ok, constraints} = TransactionConstraints.parse(request_data)
      assert constraints == []
    end

    test "returns empty constraints when given no params" do
      request_data = %{}

      {:ok, constraints} = TransactionConstraints.parse(request_data)
      assert constraints == []
    end

    test "returns validation errors when given invalid tx_types" do
      assert TransactionConstraints.parse(%{"txtypes" => 1}) == {:error, {:validation_error, "txtypes", :list}}

      assert TransactionConstraints.parse(%{"txtypes" => Enum.to_list(1..17)}) ==
               {:error, {:validation_error, "txtypes", {:max_length, 16}}}

      assert TransactionConstraints.parse(%{"txtypes" => ["1"]}) ==
               {:error, {:validation_error, "txtypes.txtype", :integer}}
    end

    test "returns a :validation_error when the given page == 0" do
      assert TransactionConstraints.parse(%{"page" => 0}) == {:error, {:validation_error, "page", {:greater, 0}}}
    end

    test "returns a :validation_error when the given page < 0" do
      assert TransactionConstraints.parse(%{"page" => -1}) == {:error, {:validation_error, "page", {:greater, 0}}}
    end

    test "returns a :validation_error when the given page is not an integer" do
      assert TransactionConstraints.parse(%{"page" => 3.14}) == {:error, {:validation_error, "page", :integer}}
      assert TransactionConstraints.parse(%{"page" => "abcd"}) == {:error, {:validation_error, "page", :integer}}
    end

    test "returns a :validation_error when the given limit == 0" do
      assert TransactionConstraints.parse(%{"page" => 0}) == {:error, {:validation_error, "page", {:greater, 0}}}
    end

    test "returns a :validation_error when the given limit < 0" do
      assert TransactionConstraints.parse(%{"page" => -1}) == {:error, {:validation_error, "page", {:greater, 0}}}
    end

    test "returns a :validation_error when the given limit is not an integer" do
      assert TransactionConstraints.parse(%{"page" => 3.14}) == {:error, {:validation_error, "page", :integer}}
      assert TransactionConstraints.parse(%{"page" => "abcd"}) == {:error, {:validation_error, "page", :integer}}
    end

    test "returns a :validation_error when the given end_datetime is not an integer" do
      assert TransactionConstraints.parse(%{"end_datetime" => 3.14}) ==
               {:error, {:validation_error, "end_datetime", :integer}}

      assert TransactionConstraints.parse(%{"end_datetime" => "abcd"}) ==
               {:error, {:validation_error, "end_datetime", :integer}}
    end
  end
end
