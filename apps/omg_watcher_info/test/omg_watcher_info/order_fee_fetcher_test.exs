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

defmodule OMG.WatcherInfo.OrderFeeFetcherTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.WatcherInfo.Fixtures

  alias OMG.Eth
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.WatcherInfo.OrderFeeFetcher
  alias OMG.WatcherInfo.TestServer
  alias OMG.WireFormatTypes

  @eth Eth.zero_address()
  @not_eth <<1::160>>
  @tx_type WireFormatTypes.tx_type_for(:tx_payment_v1)
  @str_tx_type Integer.to_string(@tx_type)

  setup do
    context = TestServer.start()
    on_exit(fn -> TestServer.stop(context) end)
    context
  end

  describe "add_fee_to_order/2" do
    test "adds the correct amount to the order", context do
      prepare_test_server(context, %{
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
      })

      order = %{
        fee: %{currency: @eth}
      }

      assert OrderFeeFetcher.add_fee_to_order(order, context.fake_addr) ==
               {:ok, Kernel.put_in(order, [:fee, :amount], 2)}
    end

    test "returns an `unexpected_fee` error when the child chain returns an unexpected fee value", context do
      prepare_test_server(context, %{
        @str_tx_type => [
          %{
            "currency" => Encoding.to_hex(@not_eth),
            "amount" => 2,
            "subunit_to_unit" => 1_000_000_000_000_000_000,
            "pegged_amount" => 4,
            "pegged_currency" => "USD",
            "pegged_subunit_to_unit" => 100,
            "updated_at" => "2019-01-01T10:10:00+00:00"
          }
        ]
      })

      assert OrderFeeFetcher.add_fee_to_order(%{fee: %{currency: @eth}}, context.fake_addr) ==
               {:error, :unexpected_fee}
    end

    test "forwards the childchain error", context do
      prepare_test_server(context, %{
        code: "fees.all:some_error",
        description: "Some errors"
      })

      assert OrderFeeFetcher.add_fee_to_order(%{fee: %{currency: @eth}}, context.fake_addr) ==
               {:error, {:client_error, %{"code" => "fees.all:some_error", "description" => "Some errors"}}}
    end
  end

  defp prepare_test_server(context, response) do
    response
    |> TestServer.make_response()
    |> TestServer.with_response(context, "/fees.all")
  end
end
