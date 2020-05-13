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
defmodule WatcherStatusTests do
  use Cabbage.Feature, async: false, file: "watcher_status.feature"

  require Logger

  defwhen ~r/^Operator requests the watcher's status$/, %{service: service}, state do
    {:ok, response} = WatcherSecurityCriticalAPI.Api.Status.status_get(WatcherSecurityCriticalAPI.Connection.new())

    body = Jason.decode!(response.body)
    {:ok, Map.put(state, :service_response, body)}
  end

  defthen ~r/^Operator can read "(?<contract_name>[^"]+)" contract address$/, %{contract_name: service_name}, state do
    assert "0x" <> _ = state.service_response["contract_addr"]["contract_name"]
    assert byte_size(state.service_response["contract_addr"]["contract_name"]) == 42

    {:ok, state}
  end
end
