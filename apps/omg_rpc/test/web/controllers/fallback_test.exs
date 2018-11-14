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

defmodule OMG.RPC.Web.Controller.FallbackTest do
  use ExUnitFixtures
  use OMG.RPC.Web.ConnCase, async: false

  test "invalid user input without validation is handled as unknown error" do
    invalid_input = %{"blknum" => "not a number"}

    assert %{
             "success" => false,
             "version" => "1",
             "data" => %{
               "object" => "error",
               "code" => "get_block::unknown_error",
               "description" => nil
             }
           } ==
             build_conn()
             |> post("/block.get", invalid_input)
             |> json_response(:ok)
  end
end
