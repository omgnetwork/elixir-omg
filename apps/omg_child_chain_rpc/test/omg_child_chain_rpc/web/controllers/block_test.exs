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

defmodule OMG.ChildChainRPC.Web.Controller.BlockTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OMG.ChildChainRPC.Web.TestHelper

  @tag fixtures: [:phoenix_sandbox]
  test "block.get endpoint rejects parameters not properly encoded as hex" do
    # there is '0x' missing in hex value
    invalid_hex = %{hash: "b3256026863eb6ae5b06fa396ab09069784ea8ea"}

    assert %{
             "success" => false,
             "data" => %{
               "object" => "error",
               "code" => "operation:bad_request",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "hash",
                   "validator" => ":hex"
                 }
               }
             }
           } = TestHelper.rpc_call(:post, "/block.get", invalid_hex)
  end

  @tag fixtures: [:phoenix_sandbox]
  test "block.get endpoint rejects improper length parameter" do
    too_short_addr = %{hash: "0x" <> String.duplicate("00", 20)}

    assert %{
             "success" => false,
             "data" => %{
               "object" => "error",
               "code" => "operation:bad_request",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "hash",
                   "validator" => "{:length, 32}"
                 }
               }
             }
           } = TestHelper.rpc_call(:post, "/block.get", too_short_addr)
  end

  @tag fixtures: [:phoenix_sandbox]
  test "block.get endpoint rejects request without parameter" do
    missing_param = %{}

    assert %{
             "success" => false,
             "data" => %{
               "object" => "error",
               "code" => "operation:bad_request",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "hash",
                   "validator" => ":hex"
                 }
               }
             }
           } = TestHelper.rpc_call(:post, "/block.get", missing_param)
  end

#   @tag fixtures: [:phoenix_sandbox]
#   test "block.get returns bad request error if hash passed in as query parameter" do
#     valid_hash = "0x" <> String.duplicate("00", 32)

#     assert %{
#              "success" => false,
#              "data" => %{
#                "object" => "error",
#                "code" => "operation:bad_request",
#                "messages" => %{
#                  "validation_error" => %{
#                    "parameter" => "hash",
#                    "validator" => ":hex"
#                  }
#                }
#              }
#            } = TestHelper.rpc_call(:post, "/block.get?hash=#{valid_hash}")
#   end
# end
