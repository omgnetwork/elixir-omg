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

  defwhen ~r/^Operator requests the watcher's status$/, %{}, state do
    {:ok, response} = WatcherSecurityCriticalAPI.Api.Status.status_get(WatcherSecurityCriticalAPI.Connection.new())

    body = Jason.decode!(response.body)
    {:ok, Map.put(state, :service_response, body)}
  end

  defthen ~r/^Operator can read "(?<contract_name>[^"]+)" contract address$/, %{contract_name: contract_name}, state do
    assert "0x" <> _ = state.service_response["data"]["contract_addr"][contract_name]
    assert byte_size(state.service_response["data"]["contract_addr"][contract_name]) == 42

    {:ok, state}
  end

  defthen ~r/^Operator can read byzantine_events$/, %{}, state do
    assert is_list(state.service_response["data"]["byzantine_events"])
    {:ok, state}
  end

  defthen ~r/^Operator can read eth_syncing$/, %{}, state do
    assert is_boolean(state.service_response["data"]["eth_syncing"])
    {:ok, state}
  end

  defthen ~r/^Operator can read in_flight_exits$/, %{}, state do
    assert is_list(state.service_response["data"]["in_flight_exits"])
    {:ok, state}
  end

  defthen ~r/^Operator can read last_mined_child_block_number$/, %{}, state do
    assert is_integer(state.service_response["data"]["last_mined_child_block_number"])
    {:ok, state}
  end

  defthen ~r/^Operator can read last_mined_child_block_timestamp$/, %{}, state do
    assert is_integer(state.service_response["data"]["last_mined_child_block_timestamp"])
    {:ok, state}
  end

  defthen ~r/^Operator can read last_seen_eth_block_number$/, %{}, state do
    assert is_integer(state.service_response["data"]["last_seen_eth_block_number"])
    {:ok, state}
  end

  defthen ~r/^Operator can read last_seen_eth_block_timestamp$/, %{}, state do
    assert is_integer(state.service_response["data"]["last_seen_eth_block_timestamp"])
    {:ok, state}
  end

  defthen ~r/^Operator can read last_validated_child_block_number$/, %{}, state do
    assert is_integer(state.service_response["data"]["last_validated_child_block_number"])
    {:ok, state}
  end

  defthen ~r/^Operator can read last_validated_child_block_timestamp$/, %{}, state do
    assert is_integer(state.service_response["data"]["last_validated_child_block_timestamp"])
    {:ok, state}
  end

  defthen ~r/^Operator can read services_synced_heights$/, %{}, state do
    services = state.service_response["data"]["services_synced_heights"]

    _ = Enum.each(services, fn service ->
      assert is_binary(service["service"])
      assert is_integer(service["height"])
    end)

    {:ok, state}
  end
end
