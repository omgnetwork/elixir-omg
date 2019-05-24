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

defmodule OMG.RPC.Web.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OMG.RPC.Web.TestHelper

  @tag fixtures: [:phoenix_sandbox]
  test "transaction.submit endpoint rejects request without parameter" do
    missing_param = %{}

    assert %{
             "success" => false,
             "data" => %{
               "object" => "error",
               "code" => "operation:bad_request",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "transaction",
                   "validator" => ":hex"
                 }
               }
             }
           } = TestHelper.rpc_call(:post, "/transaction.submit", missing_param)
  end

  @tag fixtures: [:phoenix_sandbox]
  test "transaction.submit endpoint rejects request with non hex transaction" do
    assert %{
             "success" => false,
             "data" => %{
               "object" => "error",
               "code" => "operation:bad_request",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "transaction",
                   "validator" => ":hex"
                 }
               }
             }
           } = TestHelper.rpc_call(:post, "/transaction.submit", %{transaction: "hello"})
  end
end
