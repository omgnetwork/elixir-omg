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

defmodule LoadTest.Scenario.Smoke do
  @moduledoc """
  Smoke test scenario to ensure services are up
  """
  use Chaperon.Scenario

  def run(session) do
    log_info(session, "run smoke test to make sure services are up...")

    check_child_chain_up()
    check_watcher_security_up()
    check_watcher_info_up()

    log_info(session, "smoke test done...")
  end

  defp check_child_chain_up() do
    {:ok, response} =
      LoadTest.Connection.ChildChain.client()
      |> ChildChainAPI.Api.Configuration.configuration_get()

    # some sanity check
    %{
      "data" => %{
        "contract_semver" => _contract_semver,
        "deposit_finality_margin" => _deposit_finality_margin,
        "network" => _network
      },
      "service_name" => "child_chain"
    } = Jason.decode!(response.body)
  end

  defp check_watcher_security_up() do
    {:ok, response} =
      LoadTest.Connection.WatcherSecurity.client()
      |> WatcherSecurityCriticalAPI.Api.Status.status_get()

    # some sanity check
    %{
      "data" => %{
        "byzantine_events" => _byzantine_events,
        "contract_addr" => _contract_addr
      },
      "service_name" => "watcher"
    } = Jason.decode!(response.body)
  end

  defp check_watcher_info_up() do
    {:ok, response} =
      LoadTest.Connection.WatcherInfo.client()
      |> WatcherInfoAPI.Api.Stats.stats_get()

    # some sanity check
    %{
      "data" => %{
        "average_block_interval_seconds" => _average_block_interval,
        "block_count" => _block_count
      },
      "service_name" => "watcher_info"
    } = Jason.decode!(response.body)
  end
end
