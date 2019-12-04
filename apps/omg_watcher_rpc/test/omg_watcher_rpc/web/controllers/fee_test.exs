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

defmodule OMG.WatcherRPC.Web.Controller.FeeTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Fixtures
  use OMG.Watcher.Fixtures

  alias Support.WatcherHelper

  describe "fees_all/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "fees.all endpoint rejects request with non list currencies" do
      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "currencies",
                   "validator" => ":list"
                 }
               }
             } = WatcherHelper.no_success?("/fees.all", %{currencies: "0x0000000000000000000000000000000000000000"})
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "fees.all endpoint rejects request with non hex currencies" do
      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "currencies.currency",
                   "validator" => ":hex"
                 }
               }
             } = WatcherHelper.no_success?("/fees.all", %{currencies: ["invalid"]})
    end
  end
end
