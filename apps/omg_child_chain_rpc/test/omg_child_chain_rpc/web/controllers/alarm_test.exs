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

defmodule OMG.ChildChainRPC.Web.Controller.AlarmTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.ChildChainRPC.Web.TestHelper

  setup do
    {:ok, apps} = Application.ensure_all_started(:omg_status)

    Enum.each(
      :gen_event.call(:alarm_handler, OMG.Status.Alert.AlarmHandler, :get_alarms),
      fn alarm -> :alarm_handler.clear_alarm(alarm) end
    )

    on_exit(fn ->
      Enum.each(Enum.reverse(apps), fn app -> :ok = Application.stop(app) end)
    end)
  end

  ### a very basic test of empty alarms should be sufficient, alarms encoding is
  ### covered in OMG.Utils.HttpRPC.ResponseTest
  @tag fixtures: [:phoenix_sandbox]
  test "if the controller returns the correct result when there's no alarms raised", _ do
    response = TestHelper.rpc_call(:get, "alarm.get")
    version = Map.get(response, "version")
    %{"data" => [], "success" => true, "version" => ^version} = response
  end
end
