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

defmodule OMG.Watcher.Web.Serializer.ResponseTest do
  use ExUnit.Case, async: true

  alias OMG.Watcher.DB
  alias OMG.Watcher.TestHelper
  alias OMG.Watcher.Web.Serializer.Response

  @cleaned_tx %{
    blknum: nil,
    sent_at: nil,
    txbytes: nil,
    txhash: nil,
    txindex: nil,
  }

  test "cleaning response structure: map of maps" do
    assert %{first: @cleaned_tx, second: @cleaned_tx} ==
             Response.sanitize(%{second: %DB.Transaction{}, first: %DB.Transaction{}})
  end

  test "cleaning response structure: list of maps" do
    assert [@cleaned_tx, @cleaned_tx] == Response.sanitize([%DB.Transaction{}, %DB.Transaction{}])
  end

  test "cleaning response: simple value list" do
    value = [nil, 1, "01234", :atom, [], %{}, {:skip_hex_encode, "an arbitrary string"}]
    expected_value = [nil, 1, "0x3031323334", :atom, [], %{}, "an arbitrary string"]

    assert expected_value == Response.sanitize(value)
  end

  test "cleaning response: remove nested meta keys" do
    data =
      %{
        address: "0xd5b6e653beec1f8131d2ea4f574b2fd58770d9e0",
        utxos: [
          %{
            __meta__: %{context: nil, source: {nil, "txoutputs"}, state: :loaded},
            amount: 1,
            creating_deposit: "hash1",
            creating_transaction: nil,
            currency: String.duplicate("00", 20),
            deposit: %{
              __meta__: %{context: nil, source: {nil, "txoutputs"}, state: :loaded},
              blknum: 1,
              txindex: 0,
              event_type: :deposit,
              hash: "hash1"
            },
            id: 1
          }
        ]
      }
      |> Response.sanitize()

    assert false ==
             Enum.any?(
               hd(data.utxos).deposit,
               &match?({:__meta__, _}, &1)
             )
  end

  test "decode16: decodes only specified fields" do
    expected_map = %{"key_1" => "value_1", "key_2" => "value_2", "key_3" => "value_3"}

    encoded_map = expected_map |> Response.sanitize()
    decoded_map = TestHelper.decode16(encoded_map, ["key_2"])

    assert decoded_map["key_1"] == expected_map["key_1"] |> OMG.RPC.Web.Encoding.to_hex()
    assert decoded_map["key_2"] == expected_map["key_2"]
    assert decoded_map["key_3"] == expected_map["key_3"] |> OMG.RPC.Web.Encoding.to_hex()
  end

  test "decode16: called with empty map returns empty map" do
    assert %{} == TestHelper.decode16(%{}, ["key_2"])
    assert %{} == TestHelper.decode16(%{}, [])
  end

  test "decode16: decodes all up/down/mixed case values" do
    assert %{
             "key_1" => <<222, 173, 190, 239>>,
             "key_2" => <<222, 173, 190, 239>>,
             "key_3" => <<222, 173, 190, 239>>
           } ==
             TestHelper.decode16(
               %{
                 "key_1" => "0xdeadbeef",
                 "key_2" => "0xDEADBEEF",
                 "key_3" => "0xDeadBeeF"
               },
               ["key_1", "key_2", "key_3"]
             )
  end

  test "decode16: is safe and don't process not hex-encoded values" do
    expected = %{
      "not_bin1" => 0,
      "not_bin2" => :atom,
      "not_hex" => "string",
      "not_value" => nil
    }

    assert expected == TestHelper.decode16(expected, ["not_bin1", "not_bin2", "not_hex", "not_value", "not_exists"])
  end
end
