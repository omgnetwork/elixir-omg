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

defmodule OMG.Watcher.Integration.StatusTest do
  use ExUnitFixtures
  use OMG.Watcher.Integration.Case, async: false
  alias Support.WatcherHelper

  @moduletag :integration
  @moduletag :watcher

  setup do
    {:ok, started_apps} = Application.ensure_all_started(:omg_db)
    {:ok, started_security_watcher} = Application.ensure_all_started(:omg_watcher)
    {:ok, started_watcher_api} = Application.ensure_all_started(:omg_watcher_rpc)
    _ = wait_for_web()

    on_exit(fn ->
      Application.put_env(:omg_db, :path, nil)

      (started_apps ++ started_security_watcher ++ started_watcher_api)
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end

  @tag fixtures: [:db_initialized, :root_chain_contract_config]
  test "status endpoint returns expected response format" do
    assert %{
             "last_validated_child_block_number" => 0,
             "last_validated_child_block_timestamp" => 0,
             "last_mined_child_block_number" => 0,
             "last_mined_child_block_timestamp" => 0,
             "last_seen_eth_block_number" => eth_height_now,
             "last_seen_eth_block_timestamp" => eth_timestamp_now,
             "eth_syncing" => eth_syncing,
             "byzantine_events" => [],
             "in_flight_exits" => [],
             "contract_addr" => contract_addr,
             "services_synced_heights" => services_synced_heights
           } = WatcherHelper.success?("status.get")

    assert is_integer(eth_height_now)
    assert is_integer(eth_timestamp_now)
    assert is_atom(eth_syncing)
    assert is_map(contract_addr)
    assert byte_size(contract_addr["plasma_framework"]) == 42
    assert %{"height" => height, "service" => service_name} = hd(services_synced_heights)
    assert is_integer(height)
    assert is_binary(service_name)
  end
end
