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

# defmodule OMG.ChildChain.Fees.FeedAdapterTest do
#   @moduledoc false

#   use ExUnitFixtures
#   use ExUnit.Case, async: true

#   alias FakeServer.Agents.EnvAgent
#   alias FakeServer.Env
#   alias FakeServer.HTTP.Server
#   alias OMG.ChildChain.Fees.FeedAdapter
#   alias OMG.ChildChain.Fees.JSONFeeParser
#   alias OMG.Eth

#   @moduletag :child_chain

#   @server_id :fees_all_fake_server

#   @eth Eth.zero_address()
#   @eth_hex Eth.Encoding.to_hex(@eth)
#   @payment_tx_type OMG.WireFormatTypes.tx_type_for(:tx_payment_v1)

#   @initial_price 100
#   @fee %{
#     amount: @initial_price,
#     pegged_amount: 1,
#     subunit_to_unit: 1_000_000_000_000_000_000,
#     pegged_currency: "USD",
#     pegged_subunit_to_unit: 100,
#     updated_at: DateTime.from_unix!(1_546_336_800),
#     symbol: "ETH",
#     type: :fixed
#   }

#   describe "get_fee_specs/2" do
#     setup do
#       {initial_fees, port} = fees_all_endpoint_setup(@initial_price)

#       on_exit(fn ->
#         fees_all_endpoint_teardown()
#       end)

#       {:ok,
#        %{
#          initial_fees: initial_fees,
#          actual_updated_at: :os.system_time(:second),
#          after_period_updated_at: :os.system_time(:second) - 5 * 60 - 1,
#          fee_adapter_opts: [
#            fee_change_tolerance_percent: 10,
#            stored_fee_update_interval_minutes: 5,
#            fee_feed_url: "localhost:#{port}"
#          ]
#        }}
#     end

#     test "Updates fees fetched from feed when no fees previously set", %{initial_fees: fees, fee_adapter_opts: opts} do
#       assert {:ok, ^fees, _ts} = FeedAdapter.get_fee_specs(opts, nil, 0)
#     end

#     test "Does not update when fees has not changed in long time period", %{initial_fees: fees, fee_adapter_opts: opts} do
#       assert :ok = FeedAdapter.get_fee_specs(opts, fees, 0)
#     end

#     test "Does not update when fees changed within tolerance", %{
#       initial_fees: fees,
#       actual_updated_at: updated_at,
#       fee_adapter_opts: opts
#     } do
#       _ = update_feed_price(109)
#       assert :ok = FeedAdapter.get_fee_specs(opts, fees, updated_at)
#     end

#     test "Updates when fees changed above tolerance, although under update interval", %{
#       initial_fees: fees,
#       actual_updated_at: updated_at,
#       fee_adapter_opts: opts
#     } do
#       updated_fees = update_feed_price(110)
#       assert {:ok, ^updated_fees, _ts} = FeedAdapter.get_fee_specs(opts, fees, updated_at)
#     end

#     test "Updates when fees changed below tolerance level, but exceeds update interval", %{
#       initial_fees: fees,
#       after_period_updated_at: long_ago,
#       fee_adapter_opts: opts
#     } do
#       updated_fees = update_feed_price(109)
#       assert {:ok, ^updated_fees, _ts} = FeedAdapter.get_fee_specs(opts, fees, long_ago)
#     end
#   end

#   defp make_fee_specs(amount), do: %{@payment_tx_type => %{@eth_hex => Map.put(@fee, :amount, amount)}}

#   defp parse_specs(map), do: map |> Jason.encode!() |> JSONFeeParser.parse()

#   defp get_current_fee_specs(),
#     do: :current_fee_specs |> Agent.get(& &1) |> parse_specs()

#   defp make_response(data) do
#     Jason.encode!(%{
#       version: "1.0",
#       success: true,
#       data: data
#     })
#   end

#   defp update_feed_price(amount) do
#     Agent.update(:current_fee_specs, fn _ -> make_fee_specs(amount) end)
#     {:ok, fees} = get_current_fee_specs()

#     fees
#   end

#   defp fees_all_endpoint_setup(initial_price) do
#     Agent.start(fn -> nil end, name: :current_fee_specs)

#     path = "/fees"
#     {:ok, @server_id, port} = Server.run(%{id: @server_id})
#     env = %FakeServer.Env{Env.new(port) | routes: [path]}
#     EnvAgent.save_env(@server_id, env)

#     Server.add_response(@server_id, path, fn _ ->
#       headers = %{"content-type" => "application/json"}

#       :current_fee_specs
#       |> Agent.get(& &1)
#       |> make_response()
#       |> FakeServer.HTTP.Response.ok(headers)
#     end)

#     {update_feed_price(initial_price), port}
#   end

#   defp fees_all_endpoint_teardown() do
#     :ok = Server.stop(@server_id)
#     EnvAgent.delete_env(@server_id)

#     Agent.stop(:current_fee_specs)
#   end
# end
