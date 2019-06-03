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

defmodule OMG.ChildChainRPC.Plugs.HealthTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.ChildChainRPC.Web.TestHelper
  @alarm_1 {:boot_in_progress, %{node: Node.self(), reporter: __MODULE__}}
  @alarm_2 {:ethereum_client_connection, %{node: Node.self(), reporter: __MODULE__}}
  describe "testing for boot_in_progress alarm" do
    @tag fixtures: [:phoenix_sandbox]
    test "if block.get endpoint rejects request because alarms are raised" do
      :ok = :alarm_handler.set_alarm(@alarm_1)

      assert %{
               "data" => %{
                 "code" => "operation:service_unavailable"
               }
             } = TestHelper.rpc_call(:post, "/block.get", %{})

      :ok = :alarm_handler.clear_alarm(@alarm_1)
    end

    @tag fixtures: [:phoenix_sandbox]
    test "if block.get endpoint rejects the request because of bad params when alarm is cleared" do
      :ok = :alarm_handler.clear_alarm(@alarm_1)
      missing_param = %{}

      assert catch_error(
               %{
                 "data" => %{
                   "code" => "operation:service_unavailable"
                 }
               } = TestHelper.rpc_call(:post, "/block.get", missing_param)
             )
    end
  end

  describe "testing for ethereum_client_connection alarm " do
    @tag fixtures: [:phoenix_sandbox]
    test "if block.get endpoint rejects request because alarms are raised" do
      :ok = :alarm_handler.set_alarm(@alarm_2)

      assert %{
               "data" => %{
                 "code" => "operation:service_unavailable"
               }
             } = TestHelper.rpc_call(:post, "/block.get", %{})

      :ok = :alarm_handler.clear_alarm(@alarm_2)
    end

    @tag fixtures: [:phoenix_sandbox]
    test "if block.get endpoint rejects the request because of bad params when alarm is cleared" do
      :ok = :alarm_handler.clear_alarm(@alarm_2)
      missing_param = %{}

      assert catch_error(
               %{
                 "data" => %{
                   "code" => "operation:service_unavailable"
                 }
               } = TestHelper.rpc_call(:post, "/block.get", missing_param)
             )
    end
  end
end
