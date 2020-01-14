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

defmodule OMG.ChildChainRPC.Web.Controller.FallbackTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OMG.ChildChainRPC.Web.TestHelper

  @tag fixtures: [:phoenix_sandbox]
  test "returns error for non existing method" do
    assert %{
             "success" => false,
             "data" => %{
               "object" => "error",
               "code" => "operation:not_found",
               "description" => "Operation cannot be found. Check request URL."
             }
           } = TestHelper.rpc_call(:post, "no_such.endpoint", %{})
  end
end
