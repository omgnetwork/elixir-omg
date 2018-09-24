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

defmodule OMG.Watcher.Web.Controller.FallbackTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OMG.Watcher.TestHelper

  describe "Controller.FallbackTest" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "fallback returns error for non existing endpoint" do
      %{
        "data" => %{
          "code" => "internal_server_error",
          "description" => "endpoint_not_found"
        },
        "result" => "error"
      } = TestHelper.rest_call(:get, "/non_exsisting_endpoint", nil, 500)
    end
  end
end
