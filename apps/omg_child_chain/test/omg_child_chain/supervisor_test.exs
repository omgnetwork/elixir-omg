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
defmodule OMG.ChildChain.SupervisorTest do
  @moduledoc """
  This test is here mainly to test the logic-rich part of the supervisor setup, namely the config of
  `OMG.RootChainCoordinator.Core` supplied therein
  """
  use ExUnit.Case, async: true

  alias OMG.RootChainCoordinator.Core

  setup do
    {_args, config_services} = OMG.ChildChain.CoordinatorSetup.coordinator_setup(1, 1, 1)
    init = Core.init(config_services, 10)

    pid =
      config_services
      |> Map.keys()
      |> Enum.with_index(1)
      |> Enum.into(%{}, fn {key, idx} -> {key, :c.pid(0, idx, 0)} end)

    {:ok, %{state: initial_check_in(init, Map.keys(config_services), pid), pid: pid}}
  end

  test "syncs services correctly", %{state: state, pid: pid} do
    # NOTE: this assumes some finality margines embedded in `config/test.exs`. Consider refactoring if these
    #       needs to change and break this test, instead of modifying this test!

    # start - only depositor and getter allowed to move
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, pid[:depositor])
    assert %{sync_height: 0, root_chain_height: 10} = Core.get_synced_info(state, pid[:exiter])
    assert %{sync_height: 0, root_chain_height: 10} = Core.get_synced_info(state, pid[:in_flight_exit])

    # depositor advances
    assert {:ok, state} = Core.check_in(state, pid[:depositor], 10, :depositor)
    assert %{sync_height: 10, root_chain_height: 10} = Core.get_synced_info(state, pid[:exiter])
    assert %{sync_height: 10, root_chain_height: 10} = Core.get_synced_info(state, pid[:in_flight_exit])

    # in_flight_exit advances
    assert %{sync_height: 0, root_chain_height: 10} = Core.get_synced_info(state, pid[:piggyback])
    assert {:ok, state} = Core.check_in(state, pid[:in_flight_exit], 10, :in_flight_exit)
    assert %{sync_height: 10, root_chain_height: 10} = Core.get_synced_info(state, pid[:piggyback])

    # root chain advances
    assert {:ok, state} = Core.update_root_chain_height(state, 100)
    assert %{sync_height: 99, root_chain_height: 99} = Core.get_synced_info(state, pid[:depositor])
    assert %{sync_height: 10, root_chain_height: 100} = Core.get_synced_info(state, pid[:exiter])
    assert %{sync_height: 10, root_chain_height: 100} = Core.get_synced_info(state, pid[:in_flight_exit])
    assert %{sync_height: 10, root_chain_height: 100} = Core.get_synced_info(state, pid[:piggyback])
  end

  defp initial_check_in(state, services, pid) do
    {:ok, state} =
      Enum.reduce(services, {:ok, state}, fn service, {:ok, state} ->
        Core.check_in(state, pid[service], 0, service)
      end)

    state
  end
end
