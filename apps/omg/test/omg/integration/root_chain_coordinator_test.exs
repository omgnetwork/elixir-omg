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

defmodule OMG.RootChainCoordinatorTest do
  @moduledoc """
  Smoke tests the imperative shells of `OMG.EthereumEventListener` and `OMG.RootChainCoordinator` working together
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use OMG.DB.Fixtures
  use OMG.Eth.Fixtures

  alias Support.DevHelper
  alias Support.Integration.DepositHelper

  @moduletag :integration
  @moduletag :common
  setup do
    {:ok, bus_apps} = Application.ensure_all_started(:omg_bus)
    {:ok, eth_apps} = Application.ensure_all_started(:omg_eth)
    {:ok, status_apps} = Application.ensure_all_started(:omg_status)
    apps = bus_apps ++ eth_apps ++ status_apps

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(fn app -> Application.stop(app) end)
    end)

    :ok
  end

  @tag fixtures: [:alice, :db_initialized, :root_chain_contract_config]
  test "can do a simplest sync",
       %{alice: alice} do
    coordinator_setup = %{test: [finality_margin: 0]}
    test_process = self()
    # we're starting a mock event listening machinery, which will send all deposit events to the test process to assert
    {:ok, _} =
      Supervisor.start_link(
        [
          {OMG.RootChainCoordinator, coordinator_setup},
          OMG.EthereumEventListener.prepare_child(
            service_name: :test,
            synced_height_update_key: :last_depositor_eth_height,
            get_events_callback: &OMG.Eth.RootChain.get_deposits/2,
            process_events_callback: fn events ->
              send(test_process, events)
              {:ok, []}
            end
          )
        ],
        strategy: :one_for_one
      )

    {:ok, _} = DevHelper.import_unlock_fund(alice)
    assert 1 = DepositHelper.deposit_to_child_chain(alice.addr, 10)

    assert_receive([%{amount: 10}])
  end
end
