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
defmodule OMG.Watcher.SupervisorTest do
  @moduledoc """
  This test is here mainly to test the logic-rich part of the supervisor setup, namely the config of
  `OMG.RootChainCoordinator.Core` supplied therein
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.RootChainCoordinator.Core

  @setup OMG.Watcher.CoordinatorSetup.coordinator_setup()
  @pid @setup
       |> Map.keys()
       |> Enum.with_index(1)
       |> Enum.into(%{}, fn {key, idx} -> {key, :c.pid(0, idx, 0)} end)

  deffixture state() do
    Core.init(@setup, 10)
    |> initial_check_in(Map.keys(@setup))
  end

  defp initial_check_in(state, services) do
    {:ok, state} =
      services
      |> Enum.reduce({:ok, state}, fn service, {:ok, state} -> Core.check_in(state, @pid[service], 0, service) end)

    state
  end

  @tag fixtures: [:state]
  test "syncs services correctly", %{state: state} do
    # NOTE: this assumes some finality margins embedded in `config/test.exs`. Consider refactoring if these
    #       needs to change and break this test, instead of modifying this test!

    # start - only depositor and getter allowed to move
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, @pid[:depositor])
    assert %{sync_height: 0, root_chain_height: 9} = Core.get_synced_info(state, @pid[:exit_processor])
    assert %{sync_height: 0, root_chain_height: 9} = Core.get_synced_info(state, @pid[:in_flight_exit_processor])
    assert %{sync_height: 1, root_chain_height: 10} = Core.get_synced_info(state, @pid[:block_getter])

    # depositor advances
    assert {:ok, state} = Core.check_in(state, @pid[:depositor], 9, :depositor)
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, @pid[:exit_processor])
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, @pid[:in_flight_exit_processor])

    # exit_processor advances
    assert %{sync_height: 0, root_chain_height: 9} = Core.get_synced_info(state, @pid[:exit_challenger])
    assert {:ok, state} = Core.check_in(state, @pid[:exit_processor], 9, :exit_processor)
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, @pid[:exit_challenger])

    # in flights advance
    assert %{sync_height: 0, root_chain_height: 9} = Core.get_synced_info(state, @pid[:piggyback_processor])
    assert %{sync_height: 0, root_chain_height: 9} = Core.get_synced_info(state, @pid[:competitor_processor])
    assert {:ok, state} = Core.check_in(state, @pid[:in_flight_exit_processor], 9, :in_flight_exit_processor)
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, @pid[:piggyback_processor])
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, @pid[:competitor_processor])

    assert %{sync_height: 0, root_chain_height: 9} = Core.get_synced_info(state, @pid[:piggyback_challenges_processor])
    assert {:ok, state} = Core.check_in(state, @pid[:piggyback_processor], 9, :piggyback_processor)
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, @pid[:piggyback_challenges_processor])

    assert %{sync_height: 0, root_chain_height: 9} = Core.get_synced_info(state, @pid[:challenges_responds_processor])
    assert {:ok, state} = Core.check_in(state, @pid[:competitor_processor], 9, :competitor_processor)
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, @pid[:challenges_responds_processor])

    # BlockGetter advances
    assert %{sync_height: 0, root_chain_height: 9} = Core.get_synced_info(state, @pid[:exit_finalizer])
    assert %{sync_height: 0, root_chain_height: 9} = Core.get_synced_info(state, @pid[:ife_exit_finalizer])
    assert {:ok, state} = Core.check_in(state, @pid[:block_getter], 10, :block_getter)
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, @pid[:exit_finalizer])
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, @pid[:ife_exit_finalizer])

    # root chain advances
    assert {:ok, state} = Core.update_root_chain_height(state, 100)
    assert %{sync_height: 9, root_chain_height: 99} = Core.get_synced_info(state, @pid[:exit_finalizer])
    assert %{sync_height: 9, root_chain_height: 99} = Core.get_synced_info(state, @pid[:ife_exit_finalizer])
    assert %{sync_height: 99, root_chain_height: 99} = Core.get_synced_info(state, @pid[:depositor])
    assert %{sync_height: 10, root_chain_height: 100} = Core.get_synced_info(state, @pid[:block_getter])
  end
end
