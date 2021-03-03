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

defmodule OMG.WatcherRPC.Web.Controller.FeeTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.Watcher.Fixtures
  use OMG.WatcherInfo.Fixtures

  alias OMG.Eth
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.WatcherInfo.TestServer
  alias OMG.Watcher.WireFormatTypes
  alias Support.WatcherHelper

  @eth <<0::160>>
  @tx_type WireFormatTypes.tx_type_for(:tx_payment_v1)
  @str_tx_type Integer.to_string(@tx_type)

  setup do
    context = TestServer.start()
    on_exit(fn -> TestServer.stop(context) end)
    context
  end

  describe "fees_all/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "forward a successful childchain response", context do
      childchain_response = %{
        @str_tx_type => [
          %{
            "currency" => Encoding.to_hex(@eth),
            "amount" => 2,
            "subunit_to_unit" => 1_000_000_000_000_000_000,
            "pegged_amount" => 4,
            "pegged_currency" => "USD",
            "pegged_subunit_to_unit" => 100,
            "updated_at" => "2019-01-01T10:10:00+00:00"
          }
        ]
      }

      prepare_test_server(context, childchain_response)

      ^childchain_response = WatcherHelper.success?("/fees.all")
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "raises an error gracefully when childchain is unreachable" do
      assert %{
               "code" => "connection:childchain_unreachable",
               "description" => "Cannot communicate with the childchain.",
               "object" => "error"
             } = WatcherHelper.no_success?("/fees.all")
    end

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

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "fees.all endpoint rejects request with non list tx_types" do
      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "tx_types",
                   "validator" => ":list"
                 }
               }
             } = WatcherHelper.no_success?("/fees.all", %{tx_types: 1})
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "fees.all endpoint rejects request with negative tx_types" do
      assert %{
               "object" => "error",
               "code" => "operation:bad_request",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "tx_types.tx_type",
                   "validator" => "{:greater, -1}"
                 }
               }
             } = WatcherHelper.no_success?("/fees.all", %{tx_types: [-5]})
    end
  end

  defp prepare_test_server(context, response) do
    response
    |> TestServer.make_response()
    |> TestServer.with_response(context, "/fees.all")
  end
end
