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
defmodule ServiceNameTests do
  use Cabbage.Feature, async: false, file: "service_name.feature"

  require Logger

  alias Itest.Reorg

  setup do
    Reorg.start_reorg()

    on_exit(fn ->
      Reorg.finish_reorg()
    end)
  end

  defwhen ~r/^Operator deploys "(?<service>[^"]+)"$/, %{service: service}, state do
    {:ok, response} =
      case service do
        "Child Chain" ->
          ChildChainAPI.Api.Alarm.alarm_get(ChildChainAPI.Connection.new())

        "Watcher" ->
          WatcherSecurityCriticalAPI.Api.Alarm.alarm_get(WatcherSecurityCriticalAPI.Connection.new())

        "Watcher Info" ->
          WatcherInfoAPI.Api.Alarm.alarm_get(WatcherInfoAPI.Connection.new())
      end

    body = Jason.decode!(response.body)
    {:ok, Map.put(state, :service_response, body)}
  end

  defthen ~r/^Operator can read its service name as "(?<service_name>[^"]+)"$/, %{service_name: service_name}, state do
    assert state.service_response["service_name"] == service_name

    {:ok, state}
  end
end
