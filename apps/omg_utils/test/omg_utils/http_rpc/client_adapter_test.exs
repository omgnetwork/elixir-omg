# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.Utils.HttpRPC.ClientAdapterTest do
  use ExUnit.Case, async: true

  alias OMG.Utils.HttpRPC.ClientAdapter
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Utils.HttpRPC.Response

  describe "decode16/2" do
    test "decodes only specified fields" do
      expected_map = %{"key_1" => "value_1", "key_2" => "value_2", "key_3" => "value_3"}

      encoded_map = expected_map |> Response.sanitize()
      decoded_map = ClientAdapter.decode16!(encoded_map, ["key_2"])

      assert decoded_map["key_1"] == expected_map["key_1"] |> Encoding.to_hex()
      assert decoded_map["key_2"] == expected_map["key_2"]
      assert decoded_map["key_3"] == expected_map["key_3"] |> Encoding.to_hex()
    end

    test "called with empty map returns empty map" do
      assert %{} == ClientAdapter.decode16!(%{}, [])
    end

    test "decodes all up/down/mixed case values" do
      assert %{
               "key_1" => <<222, 173, 190, 239>>,
               "key_2" => <<222, 173, 190, 239>>,
               "key_3" => <<222, 173, 190, 239>>
             } ==
               ClientAdapter.decode16!(
                 %{
                   "key_1" => "0xdeadbeef",
                   "key_2" => "0xDEADBEEF",
                   "key_3" => "0xDeadBeeF"
                 },
                 ["key_1", "key_2", "key_3"]
               )
    end

    test "is safe and fails when asked to decode anything else than hex-encoded values" do
      expected = %{
        "not_bin1" => 0,
        "not_bin2" => :atom,
        "not_hex" => "string",
        "not_value" => nil
      }

      assert_raise CaseClauseError, fn ->
        ClientAdapter.decode16!(expected, ["not_bin1"])
      end

      assert_raise CaseClauseError, fn ->
        ClientAdapter.decode16!(expected, ["not_bin2"])
      end

      assert_raise MatchError, fn ->
        ClientAdapter.decode16!(expected, ["not_hex"])
      end

      assert_raise CaseClauseError, fn ->
        ClientAdapter.decode16!(expected, ["not_value"])
      end

      assert_raise CaseClauseError, fn ->
        ClientAdapter.decode16!(expected, ["not_exists"])
      end
    end

    test "decodes lists" do
      assert %{"list" => ["\v", <<4>>]} = ClientAdapter.decode16!(%{"list" => ["0x0B", "0x04"]}, ["list"])
    end
  end
end
