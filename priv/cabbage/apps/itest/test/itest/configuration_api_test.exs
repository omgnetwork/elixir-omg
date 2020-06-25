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
defmodule ConfigurationRetrievalTests do
  use Cabbage.Feature, async: true, file: "configuration_api.feature"
  alias Itest.Reorg
  alias Itest.Transactions.Encoding
  require Logger

  setup_all do
    Reorg.finish_reorg()
    Reorg.start_reorg()

    data = ABI.encode("getVersion()", [])

    {:ok, response} =
      Ethereumex.HttpClient.eth_call(%{to: Itest.PlasmaFramework.address(), data: Encoding.to_hex(data)})

    [{contract_semver}] =
      response
      |> Encoding.to_binary()
      |> ABI.TypeDecoder.decode([{:tuple, [:string]}])

    %{
      watcher_assert_response: %{
        "contract_semver" => contract_semver,
        "deposit_finality_margin" => 10,
        "network" => "LOCALCHAIN",
        "exit_processor_sla_margin" => 30
      },
      child_chain_assert_response: %{
        "contract_semver" => contract_semver,
        "deposit_finality_margin" => 10,
        "network" => "LOCALCHAIN"
      }
    }
  end

  defwhen ~r/^Operator deploys "(?<service>[^"]+)"$/, %{service: service}, state do
    {:ok, response} =
      case service do
        "Child Chain" ->
          ChildChainAPI.Api.Configuration.configuration_get(ChildChainAPI.Connection.new())

        "Watcher" ->
          WatcherSecurityCriticalAPI.Api.Configuration.configuration_get(WatcherSecurityCriticalAPI.Connection.new())

        "Watcher Info" ->
          WatcherInfoAPI.Api.Configuration.configuration_get(WatcherInfoAPI.Connection.new())
      end

    body = Jason.decode!(response.body)

    new_state =
      state
      |> Map.put(:service_response, body)
      |> Map.put(:service, service)

    {:ok, new_state}
  end

  defthen ~r/^Operator can read its configurational values$/, _, %{service: service} = state do
    case service do
      "Child Chain" ->
        assert state.service_response["data"] == state.child_chain_assert_response

      "Watcher" ->
        assert state.service_response["data"] == state.watcher_assert_response

      "Watcher Info" ->
        assert state.service_response["data"] == state.watcher_assert_response
    end
  end
end
