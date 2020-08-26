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

defmodule OMG.WatcherRPC.Web.Validator.MergeConstraintsTest do
  use ExUnit.Case, async: true

  alias OMG.Eth.Encoding
  alias OMG.WatcherRPC.Web.Validator.MergeConstraints

  @eth Encoding.to_hex(<<0::160>>)
  @alice Encoding.to_hex(<<1::160>>)

  describe "parse/1" do
    test "fails if no match of params" do
      request_data = %{
        "foo" => "bar"
      }

      assert MergeConstraints.parse(request_data) == {:error, :operation_bad_request}
    end

    test "returns address and currency constraint when given address and currency params" do
      request_data = %{
        "address" => @alice,
        "currency" => @eth
      }

      {:ok, constraints} = MergeConstraints.parse(request_data)

      assert constraints == %{
               address: Encoding.from_hex(@alice),
               currency: Encoding.from_hex(@eth)
             }
    end

    test "fails on address and currency constraint when address not in right format" do
      request_data = %{
        "address" => "0xFake",
        "currency" => @eth
      }

      assert MergeConstraints.parse(request_data) == {:error, {:validation_error, "address", :hex}}
    end

    test "fails on address and currency constraint when currency not in right format" do
      request_data = %{
        "address" => @alice,
        "currency" => "0xFake"
      }

      assert MergeConstraints.parse(request_data) == {:error, {:validation_error, "currency", :hex}}
    end

    test "returns utxo_positions constraints when given at least 2 positions" do
      request_data = %{
        "utxo_positions" => [1, 2]
      }

      {:ok, constraints} = MergeConstraints.parse(request_data)

      assert constraints == %{
               utxo_positions: [1, 2]
             }
    end

    test "returns utxo_positions constraints when given 10 positions" do
      request_data = %{
        "utxo_positions" => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      }

      {:ok, constraints} = MergeConstraints.parse(request_data)

      assert constraints == %{
               utxo_positions: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
             }
    end

    test "fails utxo_positions constraints when given less than 2 positions" do
      request_data = %{
        "utxo_positions" => [1]
      }

      assert MergeConstraints.parse(request_data) == {:error, {:validation_error, "utxo_positions", {:min_length, 2}}}
    end

    test "fails utxo_positions constraints when given a random string" do
      request_data = %{
        "utxo_positions" => [1, 2, "foo"]
      }

      assert MergeConstraints.parse(request_data) == {:error, {:validation_error, "utxo_positions.utxo_pos", :integer}}
    end
  end
end
